package Class::PObject::Driver;

# $Id: Driver.pm,v 1.3 2003/06/08 23:22:17 sherzodr Exp $

use strict;
use Carp;
use vars ('$VERSION');

($VERSION) = '$Revision: 1.3 $' =~ m/Revision:\s*(\S+)/;

# Preloaded methods go here.
sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {    
    _stash       => { },
  };
  
  return bless($self, $class);
}



sub error {
  my ($self, $errstr) = @_;
  my $class = ref($self) || $self;
  
  no strict 'refs';
  if ( defined $errstr ) {
    #croak $errstr;
    ${ "$class\::ERROR" } = $errstr;
  }
  return ${ "$class\::ERROR" };
}




sub stash {
  my ($self, $key, $value) = @_;

  if ( defined($key) && defined($value) ) {
    $self->{_stash}->{$key} = $value;  
  }
  return $self->{_stash}->{$key};
}




sub dump {
  my $self = shift;

  require Data::Dumper;
  my $d = new Data::Dumper([$self], [ref $self]);
  return $d->Dump();
}


sub save {
  my $self = shift;
  my ($object_name, $props, $columns) = @_;

  croak "'$object_name' object doesn't support 'save()' method";
}


sub load {
  my $self = shift;
  my ($object_name, $props, $terms, $args) = @_;

  croak "'$object_name' doesn't support 'load()' method";
}


sub remove {
  my $self = shift;
  my ($object_name, $props, $id) = @_;

  croak "'$object_name' doesn't support 'remove()' method";
}


sub remove_all {
  my $self = shift;
  my ($object_name, $props) = @_;

  croak "'$object_name' doesn't support 'remove_all()' method";
}


sub DESTROY { }






1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver - driver base class and specs for Class::PObject

=head1 SYNOPSIS

  package Class::PObject::Driver::my_driver;
  use base ('Class::PObject::Driver');

=head1 WARNING

Driver specifications are in alpha state, and are subject to change in the future.

=head1 DESCRIPTION

This manual is only for those who want to develop drivers for Class::PObject. If you
just want to use Class::PObject with its default drivers, refer to L<Class::PObject> instead.

Class::PObject::Driver is a base class for all the Object drivers.

Driver is another library Class::PObject uses only when disk access is necessary.
So you can still use Class::PObject without any valid driver, but it won't be
persistent object now, would it? For that purpose, you are better off to go with 
L<Class::Struct|Class::Struct>.

Driver's certain methods will be invoked when load(), save(), remove() and remove_all() methods 
of Class::PObject are called. They receive certain arguments, and are required to return certain values.

=head1 DRIVER SPECIFICATION

All the Class::PObject drivers should subclass Class::PObject::Driver,
thus they all should begin with the following lines:

  package Class::PObject::Driver::my_driver;
  use base ('Class::PObject::Driver');

Methods that Class::PObject::Driver defines (the ones you may want to be aware of) are:

=over 4

=item stash($key [,$value])

For storing data in the driver object safely. This is mostly useful for caching the return value
of certain expensive operation that may be used over and over again. Do not try to store data specific
to class, such as its columns, or datasource. Class::PObject will try to keep the driver object for as long
as possible, even longer than current object's scope. so you really should stash() only the data that is less
likely to depend on each object. Good example is stash()ing database connection:

  $dbh = DBI->connect(...);
  $self->stash('dbh', $dbh);

  # ... later, in some other method:
  $dbh = $self->stash('dbh');

=item error($message)

Whenever an error occurs within any of driver methods, you should always call this method
with the error message, and return undef.

=back

Class::PObject::Driver also defines C<new()> - constructor. I don't think you should
know anything about it. You won't deal with it directly. however, all the driver methods
will receive the driver object as the first argument.

=head1 WHAT SHOULD DRIVER DO?

Driver should provide the following methods of its own:

=over 4

=item save($self, $object_name, \%properties, \%columns)

Whenever a user calls save() method generated by Class::PObject, that method
calls your driver's save() method is called with three arguments. The first argument is a 
string holding name of the persistent object. Second argument is a hashref representing all
the properties of the object. These are usually all the arguments given to struct() in the
form of hashref. The third argument is a hashref representing columns and their values to
be stored.

save() method will be called when a user updates an existing object and calls save() to save the
changes. It's your task to decide whether you need to update the object, or create a new one.
It's also you job to create a new id for newly stored data. save() should return undef on failure,
record id on success. If the data is newly inserted, should return newly generated id for that data.

=item load($class, $object_name, \%properties, [\%terms [, \%arguments]])

When a user asks to load an object by calling load() method, driver's load() method will be called
by Class::PObject, with at least two arguments. First argument is the name of the object,
second argument is the hashref of all the class properties, usually the ones passed to struct() as
hashref. Other arguments are the ones passed to original load(), if any.

If it could find any objects matching \%terms and \%arguments, it should return a reference
to a list of hash-references. Keys of the hash are column names, and values are their respective
values.

On failure should pass the error message to error() and return undef

=item remove($self, $object_name, \%properties, $id)

Called when remove() method is called on original Class::PObject object. Class::PObject
will call your remove() method with $object_name, \%properties and id of the object to remove.

Your task is to delete the record from the disk, and return any true value indicating success, undef
on failure.

=item remove_all($class, $object_name, \%properties)

Called when remove_all() method is called on Class::PObject object. It's job is to delete all 
the objects from the disk (scary!) and return true indicating success, or undef on failure.

=back

=head1 SEE ALSO

L<Class::PObject>, L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod B. Ruzmetov E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
