package Class::PObject::Driver::file;

# $Id: file.pm,v 1.3 2003/06/08 23:22:19 sherzodr Exp $ 

use strict;
use base ('Class::PObject::Driver');
use File::Spec;
use Carp;
use Fcntl (':DEFAULT', ':flock', ':mode');
use vars ('$filef');

$filef = 'obj%05d.cpo';

sub save {
  my ($self, $object_name, $props, $columns) = @_;

  unless ( defined $columns->{id} ) {
    $columns->{id} = $self->_generate_id($object_name, $props) or return;
  }

  my $filename = $self->_get_filename($object_name, $props, $columns->{id}) or return;

  unless ( sysopen(FH, $filename, O_WRONLY|O_CREAT|O_TRUNC, 0666) ) {
    $self->error("couldn't open '$filename': $!");
    return undef;
  }
  unless (flock(FH, LOCK_EX) ) {
    $self->error("couldn't lock '$filename': $!");
    return undef;
  }
  my $d = new Data::Dumper([$columns]);
  $d->Indent(0);
  $d->Terse(1);
  $d->Deepcopy(1);
  $d->Purity(1);
  print FH $d->Dump();
  unless( close(FH) ) {
    $self->error("couldn't save the object: $!");
    return undef;
  }
  return $columns->{id};
}




sub load {
  my $self = shift;  
  my ($object_name, $props, $terms, $args) = @_;  
  
  if ( $terms && (ref($terms) ne 'HASH') && ($terms =~m/^\d+$/) ) {
    $terms = {id => $_[2]};
  }
  
  my @data_set = ();

  if ( defined $terms->{id} ) {
    my $row =  $self->load_by_id($object_name, $props, $terms->{id}) or return;
    return ($row);
  }

  $args ||= { };

  my $dir = $self->_get_dirname($object_name, $props);
  
  require IO::Dir;
  my %files = ();
  unless(tie (%files, "IO::Dir", $dir)) {    
    $self->error("couldn't open '$dir': $!");
    return undef;
  }
  
  my $n = 0;
  while ( my ($filename, $stat) = each %files ) {
    if ( defined($args->{limit}) && (!$args->{offset}) && (!$args->{'sort'}) && ($n == $args->{limit}) ) {      
      last;
    }
    S_ISDIR($stat->mode) && next;  
    my $filef_pattern = $filef;
    $filef_pattern =~ s/\%\d*d/\\d\+/g;
    $filef_pattern =~ s/\./\\./g;    
    $filename =~ m/^$filef_pattern$/ or next;    
    unless (sysopen(FH, File::Spec->catfile($dir, $filename), O_RDONLY)) {
      $self->error("couldn't open '$filename': $!");
      return undef;
    }
    unless(flock(FH, LOCK_SH)) {
      $self->error("couldn't lock '$filename': $!");
      return undef;
    }
    local $/ = undef;
    my $datastr = <FH>;
    unless( defined $datastr ) {
      next;
    }
    my ($save_str) = $datastr =~ m/^(.*)$/;
    my $data = eval $save_str;
    if ( $self->_is_a_match($data, $terms) ) {
      push @data_set, $data;
      $n++;
    }
    close(FH);
  }
  untie(%files);
  return $self->_post_process(\@data_set, $args);
}



sub _post_process {
  my ($self, $data_set, $args) = @_;
  
  unless ( keys %$args ) {
    return @$data_set;
  }

  if ( defined($args->{'sort'}) ) {    
    $args->{direction} ||= 'asc';    
    if ( $args->{direction} eq 'desc' ) {      
      $data_set = [ sort {$b->{$args->{'sort'}} cmp $a->{$args->{'sort'}} } @$data_set];
    } else {
      $data_set = [sort {$a->{$args->{'sort'}} cmp $b->{$args->{'sort'}} } @$data_set];
    }
  }

  if ( defined $args->{limit} ) {
    $args->{offset} ||= 0;
    return (splice(@$data_set, $args->{offset}, $args->{limit}));    
  }
    
  return @$data_set;
}







sub _is_a_match {
  my ($self, $data, $terms) = @_;
  
  unless ( keys %$terms ) {
    return 1;
  }
  
  while ( my ($column, $value) = each %$terms ) { 
    if ( $data->{$column} ne $value ) {
      return 0;
    }  
  }
  return 1;
}




sub load_by_id {
  my ($self, $object_name, $props, $id) = @_;

  my $filename = $self->_get_filename($object_name, $props, $id) or return;

  unless ( sysopen(FH, $filename, O_RDONLY) ) {
    $self->error("couldn't open '$filename': $!");
    return undef;
  }
  unless(flock(FH, LOCK_SH)) {
    $self->error("couldn't lock '$filename': $!");
    return undef;
  }
  local $/ = undef;
  my $data_str = <FH>;
  close(FH);
  unless ( $data_str ) {
    $self->error("object is empty");
    return undef;
  }

  my ($save_str) = $data_str =~ m/^(.*)$/;
  my $data = eval "$save_str";
  if ( $@ ) {
    $self->error("object data is invalid: $@");
    return undef;
  }    
  return $data;
}





sub remove_all {
  my ($self, $object_name, $props) = @_;


  my $dir = $self->_get_dirname($object_name, $props);
  
  require IO::Dir;  
  my %files;
  unless (tie (%files, "IO::Dir", $dir) ) {
    $self->error("couldn't open '$dir': $!");
    return undef;
  }
  while ( my ($file, $stat) = each %files ) {
    my $filef_pattern = $filef;
    $filef_pattern =~ s/\%\d*d/\\d\+/g;
    $file =~ m/^$filef_pattern$/ or next;
    unless(unlink(File::Spec->catfile($dir, $file))) {
      $self->error("couldn't unlink '$file': $!");
      return undef;
    }
  }
  untie(%files);
  return 1;
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
  my $dir = $self->_get_dirname($object_name, $props);
  return File::Spec->catfile($dir, sprintf($filef, $id));
}


sub _get_dirname {
  my ($self, $object_name, $props) = @_;

  my $dir = $props->{datasource};
  unless ( defined $dir ) {  
    my $tmpdir = File::Spec->tmpdir();  
    $object_name =~ s/\W+/_/g;
    $dir = File::Spec->catfile($tmpdir, lc($object_name));
  }

  unless ( -e $dir ) {
    require File::Path;
    unless (File::Path::mkpath($dir) ) {
      $self->error("couldn't create datasource '$dir': $!");
      return undef;
    }
  }

  return $dir;
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

