package Class::PObject::Driver;

# $Id: Driver.pm,v 1.12 2003/08/26 20:22:34 sherzodr Exp $

use strict;
use Carp;
use Log::Agent;
use vars ('$VERSION');

$VERSION = '1.01';

# Preloaded methods go here.

sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _stash    => { },
    };
    return bless($self, $class)
}


sub DESTROY { }


sub errstr {
    my ($self, $errstr) = @_;
    my $class = ref($self) || $self;

    no strict 'refs';
    if ( defined $errstr ) {
        ${ "$class\::errstr" } = $errstr
    }
    return ${ "$class\::errstr" }
}




sub stash {
    my ($self, $key, $value) = @_;

    if ( defined($key) && defined($value) ) {
        $self->{_stash}->{$key} = $value
    }
    return $self->{_stash}->{$key}
}




sub dump {
    my $self = shift;

    require Data::Dumper;
    my $d = new Data::Dumper([$self], [ref $self]);
    return $d->Dump()
}


sub save {
    my $self = shift;
    my ($object_name, $props, $columns) = @_;

    croak "'$object_name' object doesn't support 'save()' method"
}

sub load {
    my $self = shift;
    my ($object_name, $props, $id) = @_;

    croak "'$object_name' doesn't support 'load()' method"
}



sub load_ids {
    my $self = shift;
    my ($object_name, $props, $terms, $args) = @_;

    croak "'$object_name' doesn't support  'load()' method"
}



sub remove {
    my $self = shift;
    my ($object_name, $props, $id) = @_;

    croak "'$object_name' doesn't support 'remove()' method"
}



sub remove_all {
    my $self = shift;
    my ($object_name, $props, $terms) = @_;

    my $data_set = $self->load_ids($object_name, $props, $terms);
    for ( @$data_set ) {
        $self->remove($object_name, $props, $_)
    }
    return 1
}




sub count {
    my $self = shift;
    my ($object_name, $props, $terms) = @_;

    my $data_set = $self->load_ids($object_name, $props, $terms);
    return scalar( @$data_set ) || 0
}










sub _filter_by_args {
    my ($self, $data_set, $args) = @_;

    unless ( keys %$args ) {
        return $data_set
    }
    # if sorting column was defined
    if ( defined $args->{'sort'} ) {
        # default to 'asc' sorting direction if it was not specified
        $args->{direction} ||= 'asc';
        # and sort the data set
        if ( $args->{direction} eq 'desc' ) {
            $data_set = [ sort {$b->{$args->{'sort'}} cmp $a->{$args->{'sort'}} } @$data_set]
        } else {
            $data_set = [ sort {$a->{$args->{'sort'}} cmp $b->{$args->{'sort'}} } @$data_set]
        }
    }
    # if 'limit' was defined
    if ( defined $args->{limit} ) {
        # default to 0 for 'offset' if 'offset' was not set
        $args->{offset} ||= 0;
        # and splice the data set
        return [splice(@$data_set, $args->{offset}, $args->{limit})]
    }
    return $data_set
}






sub _matches_terms {
    my ($self, $data, $terms) = @_;

    logtrc 2, "_matches_terms(%s, %s, %s)", $self, $data, $terms;
    unless ( keys %$terms ) {
        return 1
    }
    # otherwise check this data set against all the terms
    # provided. If even one of those terms are not satisfied,
    # return false
    while ( my ($column, $value) = each %$terms ) {
        if ( $data->{$column} ne $value ) {
            return 0
        }
    }
    return 1
}




sub freeze {
    my ($self, $data) = @_;

    require Storable;
    return Storable::freeze($data)
}



sub thaw {
    my ($self, $datastr) = @_;

    require Storable;
    return Storable::thaw($datastr)
}









1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver - Pobject driver specifications

=head1 SYNOPSIS

  package Class::PObject::Driver::my_driver;
  use base ('Class::PObject::Driver');

=head1 STOP!

If you just want to be able to use Class::PObject this manual is not for you.
This is for those planning to write I<pobject> drivers to support other database
systems and storage devices.

If you just want to be able to use Class::PObject, you should refer to its
L<online manual|Class::PObject> instead.

=head1 DESCRIPTION

Class::PObject::Driver is a base class for all the Object drivers.

Driver is another library Class::PObject uses only when disk access is necessary.
So you can still use Class::PObject without any valid driver, but it won't be
persistent object now, would it? If you want to creating on-the-fly, non-persistent
objects, you are better off with L<Class::Struct|Class::Struct>.

Driver's certain methods will be invoked when load(), save(), count(), remove() and remove_all() methods
of Class::PObject are called. They receive certain arguments, and are required to return certain values.

=head1 DRIVER SPECIFICATION

All the Class::PObject drivers should subclass Class::PObject::Driver,
thus they all should begin with the following lines:

  package Class::PObject::Driver::my_driver;
  use base ('Class::PObject::Driver');

Exceptions may be L<DBI|DBI>-related drivers, which are better off subclassing
L<Class::PObject::Driver::DBI|Class::PObject::Driver::DBI> and DBM-related drivers, 
that are better off subclassing L<Class::PObject::Driver::DBM|Class::PObject::Driver::DBM>

Methods that L<Class::PObject::Driver> defines are:

=over 4

=item stash($key [,$value])

For storing data in the driver object safely. This is mostly useful for caching the return value
of certain expensive operations that may be used over and over again. Do not try to store data specific
to individual pobject classes, such as its columns, or datasource. Class::PObject will try to
keep the driver object for as long as possible, even longer than current pobject's scope. So you
really should stash() only the data that is less likely to depend on each pobject. Good example is
stash()ing database connection.

For example, consider the following example:

  $dbh = DBI->connect(...);
  $self->stash('dbh', $dbh);    # WRONG!

  # ... later, in some other method:
  $dbh = $self->stash( 'dbh' );

The above example works as expected in some cases, since most projects use the same
database connection to access several pobjects. So it's safe to associate the database
handle with string I<'dbh'>.

However, sometimes several I<pobjects> can use several database connections. In cases like
these the above code will not work. Because the first created $dbh will also be used
to synchronize the second object data. Instead, you should do something like this:

    $dbh = DBI->connect(...);
    $self->stash($dsn, $dbh);   # RIGHT!

    # ... later, in some other method:
    $dbh = $self->stash( $dsn );

C<$dsn> in the above example is analogous to I<Name> DBI attribute

=item errstr($message)

Whenever an error occurs within any of driver methods, you should always call this method
with the error message, and return undef.

=back

Class::PObject::Driver also defines C<new()> - constructor. I don't think you should
know anything about it. You won't deal with it directly. All the driver methods
receive the driver object as the first argument.

=head1 WHAT SHOULD DRIVER DO?

Driver should inherit from either Class::PObject::Driver or L<Class::PObject::Driver::DBI>,
and override several methods with those relevant to the specific storage method/device.

All the driver methods accept at least 3 same arguments: C<$self> - driver object,
C<$pobject_name> - name of the pobject and C<\%properties> hashref of all the properties
as passed to C<pobject()> as the second (or first) argument in the form of a hashref.

These arguments are relevant to all the driver methods, unless noted otherwise.

On failure all the driver methods should pass the error message to C<errstr()> method as the
first and the only argument, and return undef.

On success they either should return a documented value (below), or boolean value whenever
appropriate.

=head2 REQUIRED METHODS

If you are inheriting from Class::PObject::Driver, you should provide following methods
of your own.

=over 4

=item C<save($self, $pobject_name, \%properties, \%columns)>

Whenever a user calls C<save()> method of I<pobject>, that method calls your driver's
C<save()> method.

In addition to standard arguments, C<save()> accepts C<\%columns>, which is a
hash of column names and their respective values to be stored into disk.

It's the driver's obligation to figure whether the object should be stored, or updated.

New objects usually do not have C<id> defined. This is a clue that it is a new object,
thus you need to create a new ID and store the object into disk. If the I<id> exists,
it mostly means that object already should exist in the disk, and thus you need to update
it.

On success C<save()> should always return I<id> of the object stored or updated.

=item C<load_ids($self, $pobject_name, \%properties, [\%terms [, \%arguments]])>

When a user asks to load an object by calling C<load()> method of I<pobject>, driver's
C<load_ids()> method will be called by L<Class::PObject>.

In addition to aforementioned 3 standard arguments, it may (or may not) receive
C<\%terms> - terms passed to initial pobject's load() method as the first argument
and C<\%args> - arguments passed to pobject's load() method as the second argument.

Should return an arrayref of object ids.

=item C<load($self, $object_name, \%properties, $id)>

Is called to retrieve an individual object from the database. Along with standard
arguments, it receives C<$id> - ID of the record to be retrieved. On success should
return hash-ref of column/value pairs. 

=item C<remove($self, $object_name, \%properties, $id)>

Called when remove() method is called on pobject.

In addition to standard arguments, it will receive C<$id> - ID of the object that needs to be removed.

Your task is to delete the record from the disk, and return any true value indicating success.

=back

=head2 OPTIONAL METHODS

You may choose not to override the following methods if you don't want to. In that case
Class::PObject::Driver will try to implement these functionality based on other available
methods.

So why are these methods required if their functionality can be achieved using other methods?
Some drivers, especially RDBMS drivers, may perform these tasks much more efficiently by applying
special optimizations to queries. In cases like these, you may want to override these methods.
If you don't, default methods still perform as intended, but may not be as efficient.

=over 4

=item C<remove_all($self, $object_name, \%properties [,\%terms])>

Called when remove_all() method is called on pobject. It's job is to delete all
the objects from the disk.

In addition to standard arguments, it may (or may not) receive C<\%terms>, which is a set of key/value
pairs. All the objects matching these terms should be deleted from the disk.

Should return true on success.

=item C<count($self, $object_name, \%properties, [,\%terms])>

Counts number of objects stored in disk.

In addition to standard arguments, may (or may not) accept C<\%terms>, which is a set of key/value
pairs. If C<\%terms> is present, only the count of objects matching these terms should be returned.

On success should return a digit, representing a count of objects.

=back

=head1 SEE ALSO

L<Class::PObject::Driver::DBI>

=head1 AUTHOR

Sherzod B. Ruzmetov E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
