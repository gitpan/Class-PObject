package Class::PObject::Driver::file;

# $Id: file.pm,v 1.5 2003/06/19 21:40:20 sherzodr Exp $ 

use Carp;
use strict;
use File::Spec;
use Data::Dumper;
use base ('Class::PObject::Driver');
use Fcntl (':DEFAULT', ':flock', ':mode');

use vars ('$filef');

# this is the format of the object file to be stored:
$filef = 'obj%05d.cpo';

sub save {
  my ($self, $object_name, $props, $columns) = @_;
  
  # if 'id' does not already exist, we should create new id:
  unless ( defined $columns->{id} ) {
    $columns->{id} = $self->_generate_id($object_name, $props) or return;
  }

  # _get_filename() returns the name of the file this particular object should
  # be stored. Look into _get_filename() for details
  my $filename = $self->_get_filename($object_name, $props, $columns->{id}) or return;
  
  # if we can't open the file, we set error message, and return undef
  unless ( sysopen(FH, $filename, O_WRONLY|O_CREAT|O_TRUNC, 0666) ) {
    $self->error("couldn't open '$filename': $!");
    return undef;
  }
  # we do the same if we can't get exclusive lock on the file
  unless (flock(FH, LOCK_EX) ) {
    $self->error("couldn't lock '$filename': $!");
    return undef;
  }
  # and store frozen data into file:
  print FH $self->freeze($columns);
  # if we can't close the filehandle, it means we couldn't store it.
  unless( close(FH) ) {
    $self->error("couldn't save the object: $!");
    return undef;
  }
  # if everything went swell, we should return object id
  return $columns->{id};
}




sub load {
  my $self = shift;  
  my ($object_name, $props, $terms, $args) = @_;
  
  # if we're asked to load by id, let's take a shortcust instead,
  # thus much faster
  if ( $terms && (ref($terms) ne 'HASH') && ($terms =~m/^\d+$/) ) {
    return $self->load_by_id($object_name, $props, $terms) or return;
  }
  
  # if we come this far, we're being asked to return either all the objects,
  # or by some criteria
  my @data_set  = ( );
  $args       ||= { };

  # to do it, we need to figure out which directory the objects of this
  # type are most likely to be stored
  my $dir = $self->_get_dirname($object_name, $props) or return;
  
  # and iterate through each object file:
  require IO::Dir;
  my %files = ();
  unless(tie (%files, "IO::Dir", $dir)) {    
    $self->error("couldn't open '$dir': $!");
    return undef;
  }
  
  my $n = 0;
  while ( my ($filename, $stat) = each %files ) {
    # if 'limit' was given, and 'offset' is missing and sort is not given,
    # then check we have already reached our 'limit'
    if ( defined($args->{limit}) && (!$args->{offset}) && (!$args->{'sort'}) && ($n == $args->{limit}) ) {
      # if so, exist the loop
      last;
    }
    # if it is a directory, then skip to the next file
    S_ISDIR($stat->mode) && next;  
    
    # defining a regex pattern to check againts the filename to determine
    # if it can be the file object stored in
    my $filef_pattern = $filef;
    $filef_pattern =~ s/\%\d*d/\\d\+/g;
    $filef_pattern =~ s/\./\\./g;    
    $filename =~ m/^$filef_pattern$/ or next;
    # we open the file with read-only flag
    unless (sysopen(FH, File::Spec->catfile($dir, $filename), O_RDONLY)) {
      $self->error("couldn't open '$filename': $!");
      return undef;
    }
    unless(flock(FH, LOCK_SH)) {
      $self->error("couldn't lock '$filename': $!");
      return undef;
    }
    local $/ = undef;
    my $datastr = <FH>; close(FH);
    unless( defined $datastr ) {
      next;
    }
    my $data = $self->thaw($datastr);
    if ( $self->_is_a_match($data, $terms) ) {
      push @data_set, $data;
      $n++;
    }
  }
  # untying the directory
  untie(%files);

  # returning post-processed data set
  return $self->_post_process(\@data_set, $args);
}



# main purpose of _post_process is to splice the data set
# according to arguments passed to load():
sub _post_process {
  my ($self, $data_set, $args) = @_;
  
  unless ( keys %$args ) {
    return $data_set;
  }

  # if sorting column was defined
  if ( defined($args->{'sort'}) ) {    
    # default to 'asc' sorting direction if it was not specified
    $args->{direction} ||= 'asc';
    # and sort the data set
    if ( $args->{direction} eq 'desc' ) {      
      $data_set = [ sort {$b->{$args->{'sort'}} cmp $a->{$args->{'sort'}} } @$data_set];
    } else {
      $data_set = [sort {$a->{$args->{'sort'}} cmp $b->{$args->{'sort'}} } @$data_set];
    }
  }

  # if 'limit' was defined
  if ( defined $args->{limit} ) {
    # default to 0 for 'offset' if 'offset' was not set
    $args->{offset} ||= 0;
    # and spliace the data set
    return [splice(@$data_set, $args->{offset}, $args->{limit})];
  }

  # return the set
  return $data_set;
}







# _is_a_match determines if this particular data-set matches
# our terms
sub _is_a_match {
  my ($self, $data, $terms) = @_;
  
  # if no terms were defined, return true
  unless ( keys %$terms ) {
    return 1;
  }
  
  # otherwise check this data set againsts all the terms
  # provided. If even one of those terms are not satisfied,
  # return false
  while ( my ($column, $value) = each %$terms ) { 
    if ( $data->{$column} ne $value ) {
      return 0;
    }  
  }

  # if we reached this far, all the terms have been satisfied.
  return 1;
}




# load_by_id() is called only while object is to be retrieved by its id
sub load_by_id {
  my ($self, $object_name, $props, $id) = @_;

  # determine the name of the file for this object
  my $filename = $self->_get_filename($object_name, $props, $id) or return;
  
  # open that file
  unless ( sysopen(FH, $filename, O_RDONLY) ) {
    $self->error("couldn't open '$filename': $!");
    return undef;
  }
  # lock the filehandle
  unless(flock(FH, LOCK_SH)) {
    $self->error("couldn't lock '$filename': $!");
    return undef;
  }
  # undefined record seperator
  local $/ = undef;
  # slurp the whole file in
  my $data_str = <FH>;
  close(FH);
  unless ( $data_str ) {
    $self->error("object is empty");
    return undef;
  }

  return [$self->thaw($data_str)];
}




sub remove {
  my ($self, $object_name, $props, $id) = @_;

  my $dir = $props->{datasource} || File::Spec->tmpdir();
  my $filename = $self->_get_filename($object_name, $props, $id);
  unless ( unlink($filename) ) {
    $self->error("couldn't unlink '$filename': $!");
    return undef;
  }
  return 1;
}






sub _generate_id {
  my ($self, $object_name, $props) = @_;
  
  my $dir = $self->_get_dirname($object_name, $props) or return;

  my $filename = File::Spec->catfile($dir, 'counter.cpo');
  
  unless (sysopen(FH, $filename, O_RDWR|O_CREAT)) {
    $self->error("couldn't open/create '$filename': $!");
    return undef;
  }
  unless (flock(FH, LOCK_EX) ) {
    $self->error("couldn't lock '$filename': $!");
    return undef;
  }
  my $num = <FH> || 0;
  unless (seek(FH, 0, 0)) {
    $self->error("couldn't seek to the start of '$filename': $!");
    return undef;
  }
  unless (truncate(FH, 0)) {
    $self->error("couldn't truncate '$filename': $!");
    return undef;
  }
  print FH ++$num, "\n";
  unless(close(FH)) {
    $self->error("couldn't update '$filename': $!");
    return undef;
  }
  return $num;
}




sub _get_filename {
  my ($self, $object_name, $props, $id) = @_;

  unless ( defined $id ) {
    croak "Usage: _file_name(\$id)";
  }
  my $dir = $self->_get_dirname($object_name, $props) or return;
  return File::Spec->catfile($dir, sprintf($filef, $id));
}


sub _get_dirname {
  my ($self, $object_name, $props) = @_;

  my $dir = $props->{datasource};

  # if 'datasource' was not specified, we should
  # create a location for object of this type in the
  # system's temp folder:
  unless ( defined $dir ) {  
    my $tmpdir = File::Spec->tmpdir();  
    $object_name =~ s/\W+/_/g;
    $dir = File::Spec->catfile($tmpdir, lc($object_name));
  }

  # if the directory that we just created doesn't exist,
  # we should create it
  unless ( -e $dir ) {
    require File::Path;
    unless (File::Path::mkpath($dir) ) {
      $self->error("couldn't create datasource '$dir': $!");
      return undef;
    }
  }
  
  # return the directory
  return $dir;
}





sub freeze {
  my ($self, $data) = @_;

  require Data::Dumper;
  my $d = new Data::Dumper([$data]);
  $d->Indent(0);
  $d->Terse(1);
  $d->Deepcopy(1);
  $d->Purity(1);
  return $d->Dump();
}



sub thaw {
  my ($self, $datastr) = @_;
  
  # to make -T happy
  my ($safestr) = $datastr =~ m/^(.*)$/;

  # creating a new compartment to compile this code safely.
  require Safe;
  my $cpt = new Safe();
  return $cpt->reval($safestr)
}








1;

__END__;

=pod

=head1 NAME

Class::PObject::Driver::file - default driver for Class::PObject

=head1 SYNOPSIS  

  pobject Person => {
    columns   => ['id', 'name', 'email'],
    driver    => 'file',
    datasource=> 'data/person'
  };


=head1 DESCRIPTION

Class::PObject::Driver::file is a default driver used by Class::PObject. The only required class property is 'columns'. If 'driver' is missing, Class::PObject will default to 'file' automatically. If 'datasource' is missing, the driver will  default to system's temporary directory, which is /tmp on most *nix systems, and C:\TEMP on Windows.

This data source is a folder in your operating system, inside which objects will store themselves. So it's required each object to have its own distinctive data source location.

=head1 OBJECT STORAGE

Each object is stored as a separate file. Each file has the same format as "obj%05d.cpo" where "%05d" will be replaced with the id of the object, zeros padded if necessary. Extension '.cpo' stands for B<C>lass::B<PO>bject.

=head1 SERIALIZATION

Objects are serialized using standard L<Data::Dumper> and is represented as a hash-table.

=head1 ID GENERATION

'file' driver keeps its own record counter for generating auto-incrementing values for subsequent
records more efficiently. Record counter is stored inside the 'datasource' folder in a file called "counter.cpo".
Newly created records should not be passed any ids, for it my cause undocumented problems.

In case the record counter is deleted accidentally, the driver doesn't re-create it, but I believe some sort of safety net should be added.

=head1 NOTES

Since the driver doesn't keep an index of any kind, the most efficient way of loading the data is by its id
or by simple load() syntax. load(undef, {limit=>n}) should also be fast:

  my $p       = Person->load(451);
  my @people  = Person->load();
  my @group   = Person->load(undef, {limit=>100});

as load() becomes complex, the performance gets degrading:

  my @people = Person->load({name=>"Sherzod"}, {sort=>'age', direction=>'desc', limit=>10, offset=>4});

To perform the above search, the driver walks through all the objects available in the 'datasource', pushes all the objects matching 'name="sherzod"' to the stack, then, just before returning the data set, performs sort, limit and offset calculations. As you could imagine, as the number of objects in the datasource increases, this operation may become more and more costly.

=head1 SEE ALSO

L<Class::PObject>, L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

=cut

