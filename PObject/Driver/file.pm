package Class::PObject::Driver::file;

# $Id: file.pm,v 1.11 2003/08/23 13:15:12 sherzodr Exp $

use strict;
use File::Spec;
use Log::Agent;
use base ('Class::PObject::Driver');
use Fcntl (':DEFAULT', ':flock', ':mode');
use vars ('$f');

# defining the format of the object file. Sample would be 'obj00129.cpo'
$f = 'obj%05d.cpo';

# called when pobject's save() method is called. Note: this is not
# the same as save() method as the one called by pobject. This is different!
sub save {
    my ($self, $object_name, $props, $columns) = @_;

    # if 'id' does not already exist, we're being asked to save a newly
    # created object. Before we do that, we create a new id for the object:
    if ( defined $columns->{id} ) {
        logtrc 2, "'id' (%d) already exists. Updating the object data", $columns->{id}

    } else {
        $columns->{id} = $self->generate_id($object_name, $props) or return;
        logtrc 2, "'id' was missing, created a new id (%d)", $columns->{id}
    }

    # _filename() returns the name of the file this particular object should
    # be stored in. Look into _filename() for details
    my $filename = $self->_filename($object_name, $props, $columns->{id}) or return;

    # if we can't open the file, we set error message, and return undef
    unless ( sysopen(FH, $filename, O_WRONLY|O_CREAT|O_TRUNC, 0666) ) {
        $self->errstr("couldn't open '$filename': $!");
        logerr $self->errstr;
        return undef
    }
    # we do the same if we can't get exclusive lock on the file
    unless (flock(FH, LOCK_EX) ) {
        $self->errstr("couldn't lock '$filename': $!");
        logerr $self->errstr;
        return undef
    }

    # and store frozen data into file:
    print FH $self->freeze($columns);
    # if we can't close the file handle, it means we couldn't store it.
    unless( close(FH) ) {
        $self->errstr("couldn't save the object: $!");
        logerr $self->errstr;
        return undef
    }
    # if everything went swell, we should return object id
    logtrc 2, "save() successful. Object id is %d", $columns->{id};
    return $columns->{id}
}




sub load {
    my $self = shift;
    my ($object_name, $props, $terms, $args) = @_;

    # if we're asked to load by id, let's take a shortcut instead,
    # thus more efficient
    if ( $terms && (ref($terms) ne 'HASH') && ($terms =~m/^\d+$/) ) {
        logtrc 2, "loading by 'id' (%d)", $terms;
        return $self->load_by_id($object_name, $props, $terms) or return
    }

    logtrc 2, "loading object by 'terms' and/or 'args'";

    # if we come this far, we're being asked to return either all the objects,
    # or by some criteria
    my @data_set  = ( );
    $args       ||= { };

    # to do it, we need to figure out which directory the objects of this
    # type are most likely to be stored. For details look into '_dir()'
    my $object_dir = $self->_dir($object_name, $props) or return;

    # and iterate through each object file. For some reason I prefer using
    # IO::Dir for retrieving objects, seems 'cleaner' this way
    require IO::Dir;
    my %files = ();
    unless(tie %files, "IO::Dir", $object_dir) {
        $self->errstr("couldn't open '$object_dir': $!");
        logerr $self->errstr;
        return undef
    }

    logtrc 2, "Browsing '%s'", $object_dir;

    my $n = 0;
    while ( my ($filename, $stat) = each %files ) {
        # if 'limit' was given, and 'offset' is missing and sort is not given,
        # then check we have already reached our 'limit'. Otherwise, we need to
        # load all the objects to the memory before we can return the data set
        if ( defined($args->{limit}) && (!$args->{offset}) && (!$args->{'sort'}) && ($n == $args->{limit}) ) {
            logtrc 2, "only 'limit' (%d) was defined and been met. Exiting the loop now", $args->{limit};
            last
        }
        # if it is a directory, then skip to the next file
        if ( S_ISDIR($stat->mode) ) {
            logtrc 2, "'%s' is a directory. Skipping to the next", $filename;
            next
        }

        # defining a regex pattern to check against the filename to determine
        # if it can be the file object stored in
        my $filef_pattern = $f;
        $filef_pattern    =~ s/\%\d*d/\\d\+/g;
        $filef_pattern    =~ s/\./\\./g;

        unless ( $filename =~ m/^$filef_pattern$/ ) {
            logtrc 2, "'%s' doesn't match the regex '%s'. Skipping", $filename, $filef_pattern;
            next
        }
        # we open the file with read-only flag
        unless (sysopen(FH, File::Spec->catfile($object_dir, $filename), O_RDONLY)) {
            $self->errstr("couldn't open '$filename': $!");
            logerr $self->errstr;
            return undef
        }

        unless(flock(FH, LOCK_SH)) {
            $self->errstr("couldn't lock '$filename': $!");
            logerr $self->errstr;
            return undef
        }
        local $/ = undef;
        my $datastr = <FH>; close(FH);
        unless( defined $datastr ) {
            next
        }
        my $data = $self->thaw($datastr);
        if ( $self->_matches_terms($data, $terms) ) {
            push @data_set, $data;
            $n++
        }
    }
    untie(%files);

    # returning post-processed data set
    logtrc 2, "%d objects were found matching the 'terms'", scalar(@data_set);
    return $self->_filter_by_args(\@data_set, $args)
}














# load_by_id() is called only while object is to be retrieved by its id
sub load_by_id {
    my ($self, $object_name, $props, $id) = @_;

    # determine the name of the file for this object
    my $filename = $self->_filename($object_name, $props, $id) or return;

    # open that file
    unless ( sysopen(FH, $filename, O_RDONLY) ) {
        $self->errstr("couldn't open '$filename': $!");
        return undef
    }
    # lock the file handle
    unless(flock(FH, LOCK_SH)) {
        $self->errstr("couldn't lock '$filename': $!");
        return undef
    }
    # undefined record separator
    local $/ = undef;
    # slurp the whole file in
    my $data_str = <FH>;
    close(FH);
    unless ( $data_str ) {
        $self->errstr("object is empty");
        return undef
    }
    return [$self->thaw($data_str)]
}




sub remove {
    my ($self, $object_name, $props, $id) = @_;

    my $filename = $self->_filename($object_name, $props, $id);
    unless ( unlink($filename) ) {
        $self->errstr("couldn't unlink '$filename': $!");
        return undef
    }
    return 1
}




sub generate_id {
    my ($self, $object_name, $props) = @_;

    my $dir = $self->_dir($object_name, $props) or return;

    my $filename = File::Spec->catfile($dir, 'counter.cpo');

    unless (sysopen(FH, $filename, O_RDWR|O_CREAT)) {
        $self->errstr("couldn't open/create '$filename': $!");
        return undef
    }
    unless (flock(FH, LOCK_EX) ) {
        $self->errstr("couldn't lock '$filename': $!");
        return undef
    }
    my $num = <FH> || 0;
    unless (seek(FH, 0, 0)) {
        $self->errstr("couldn't seek to the start of '$filename': $!");
        return undef
    }
    unless (truncate(FH, 0)) {
        $self->errstr("couldn't truncate '$filename': $!");
        return undef
    }
    print FH ++$num, "\n";
    unless(close(FH)) {
        $self->errstr("couldn't update '$filename': $!");
        return undef
    }
    return $num
}




sub _filename {
    my ($self, $object_name, $props, $id) = @_;

    unless ( $object_name && $id ) {
        logcroak "Usage: _filename(\$id)";
    }
    my $dir = $self->_dir($object_name, $props) or return;
    return File::Spec->catfile($dir, sprintf($f, $id))
}


sub _dir {
    my ($self, $object_name, $props) = @_;

    my ($object_dir, $object_name_as_str);
    my $dir         = $props->{datasource};

    # if 'datasource' was not specified, we should
    # create a location for object of this type in the
    # system's temp folder:
    unless ( defined $dir ) {
        $dir = File::Spec->tmpdir()
    }

    # creating a dirified version of the object name
    $object_name_as_str = $object_name;
    $object_name_as_str =~ s/\W+/_/g;
    $object_dir         = File::Spec->catfile($dir, $object_name_as_str);

    # if the directory that we just created doesn't exist,
    # we should create it
    unless ( -e $object_dir ) {
        require File::Path;
        unless (File::Path::mkpath($object_dir) ) {
            $self->errstr("couldn't create datasource '$object_dir': $!");
            return undef
        }
    }

  # return the directory
  return $object_dir
}







1;

__END__;

=pod

=head1 NAME

Class::PObject::Driver::file - Default PObject driver

=head1 SYNOPSIS

  pobject Person => {
    columns   => ['id', 'name', 'email']
    datasource=> 'data'
  };

=head1 DESCRIPTION

Class::PObject::Driver::file is a default driver used by L<Class::PObject|Class::PObject>.
Class::PObject::Driver::file is a direct subclass of L<Class::PObject::Driver>. Refer to its
L<manual|Class::PObject::Driver> for more details.

The only required class property is I<columns>. If I<driver> is missing, Class::PObject will
default to I<file> automatically. If I<datasource> is missing, the driver will  default to your
system's temporary directory, which is F</tmp> on most *nix systems, and F<C:\TEMP> on Windows.

This data source is a folder in your operating system, inside which objects will be stored.
Pobject will create a folder for each object type inside the I<datasource> folder, and will store
all the objects of the same type in their own folders.

=head1 SUPPORTED FEATURES

Class::PObject::Driver::file overrides following methods of Class::PObject::Driver

=over 4

=item * save()

=item * load()

=item * remove()

=back

In addition to standard methods, it also defines following methods of its own. These methods
are just private/utility methods that are not invoked by PObjects directly. But knowledge of these
methods may prove useful if you want to subclass this driver to cater it to your needs.

=over 4

=item *

C<load_by_id($self, $pobject_name, \%properties, $id)> is called from within C<load()> method
when an object is to be loaded by id. This happens if the pobject invokes C<load()>
method with a single digit:

    $article = Article->load(443)

This  is the most efficient way of loading objects using I<file> driver.

Although the effect of saying

    $article = Article->load({id=>443})

is the same as the previous example, the latter will bypass optimizer, thus will not invoke
C<load_by_id()> method.

=item *

C<generate_id($self, $pobject_name, \%properties)> is called whenever a new object is to be stored
and new, unique ID is to be generated.

=item *

C<_dir($self, $pobject_name, \%propertries)> is called to get the path to a directory where
objects of this type are to be stored. If the directory hierarchy doesn't exist, it will create
necessary directories automatically, assuming it has necessary permissions.

=item *

C<_filename($self, $pobject_name, \%properties)> is called to get a path to a file this particular
object should be stored into. C<_filename()> will call C<_dir()> method to get the object directory,
and builds a filename inside this directory.

=item *

C<freeze($self, \%data)> and C<thaw($self, $string)> are used to serialize and de-serialize the data
to make it suitable for storing into disk. By default C<freeze()> and C<thaw()> use
L<Data::Dumper|Data::Dumper>. If you want to use some other method, you can subclass
Class::PObject::Driver::file and define your own C<freeze()> and C<thaw()> methods:

    # Inside Class/PObject/Driver/my_file.pm
    package Class::PObject::Driver::my_file;
    use base ('Class::PObject::Driver::file');
    require Storable;

    sub freeze {
        my ($self, $data) = @_;
        return Storable::freeze($data)
    }

    sub thaw {
        my ($self, $string) = @_;
        return Storable::thaw($string)
    }

    1;

    # Inside Article.pm, for example:
    package Article;
    pobject {
        columns => ['id', 'title', 'author', 'content'],
        driver  => 'my_file'
    };

=back

=head1 OBJECT STORAGE

Each object is stored as a separate file. File name pattern for each object file is defined in
C<$Class::PObject::Driver::file::f> global variable, is is C<obj%05.cpo> by default, where C<%05>
will be replaced with the I<id> of the object, zeroes padded if necessary.

B<Note:> extension '.cpo' stands for B<C>lass::B<PO>bject.

=head1 SERIALIZATION

Objects are serialized using standard L<Data::Dumper|Data::Dumper>

=head1 ID GENERATION

I<file> driver keeps its own record counter for generating auto-incrementing values for subsequent
records more efficiently. Record counter is stored inside the object directory (C<_dir()> method returns
the path to this folder) in a file called "counter.cpo".

=head2 WARNING

Removing F<counter.cpo> from the directory will force PObject to reset object ids. This may be a problem
if there already are objects in the directory, and they may be overridden by new ids. I realize
this is a scary limitation, which will be eventually addressed.

In the meanwhile, just don't make habit of removing F<counter.cpo>!

=head1 EFFICIENCY

Since the driver doesn't keep an index of any kind, the most efficient way of loading the data is by its id.
A relatively simple C<load(undef, {limit=>n})> syntax is also relatively fast.

  my $p       = Person->load(451);
  my @people  = Person->load();
  my @group   = Person->load(undef, {limit=>100});

as load() becomes complex, the performance gets degrading:

  my @people = Person->load({name=>"Sherzod"}, {sort=>'age', direction=>'desc', limit=>10, offset=>4});

To perform the above search, the driver walks through all the objects available in the I<datasource>, pushes all the objects matching 'name="sherzod"' to the data-set, then, just before returning the data set, performs sort, limit and offset calculations. 

As you imagine, as the number of objects in the datasource increases, this operation will become more costly.

=head1 SEE ALSO

L<Class::PObject>, L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

=cut
