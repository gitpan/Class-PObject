package Class::PObject::Driver::DBM;

# $Id: DBM.pm,v 1.2 2003/08/23 14:31:29 sherzodr Exp $

use strict;
use Carp;
use Class::PObject::Driver;
use File::Spec;
use Fcntl (':DEFAULT', ':flock');
use vars ('$VERSION', '@ISA', '$lock');

@ISA = ('Class::PObject::Driver');

$VERSION = '1.00';


sub save {
    my ($self, $object_name, $properties, $columns) = @_;
    
    $self->_write_lock($object_name, $properties);
    my $dbh = $self->dbh($object_name, $properties) or return undef;

    unless ( $columns->{id} ) {
        my $lastid = $dbh->{_lastid} || 0;
        $columns->{id} = ++$dbh->{_lastid}
    }

    $dbh->{ "!ID:" . $columns->{id} } = $self->freeze($columns);
    $self->_unlock();
    return $columns->{id}
}



sub load {
    my ($self, $object_name, $properties, $terms, $args) = @_;

    $self->_read_lock($object_name, $properties);
    my $dbh = $self->dbh($object_name, $properties) or return undef;

    if ( $terms && (ref($terms) ne 'HASH') && ($terms =~ /^\d+$/) ) {
        return [$self->thaw( $dbh->{"!ID:" . $terms} )]
    }

    my @data_set = ();
    my $n = 0;
    while ( my ($k, $v) = each %$dbh ) {
        if ( $args && $args->{limit} && !$args->{offset} && !$args->{sort} ) {
            if ( $n++ == $args->{limit} ) {
                last
            }
        }
        $k =~ /!ID:/ or next;
        my $data = $self->thaw( $v );

        if ( $self->_matches_terms($data, $terms) ) {
            push @data_set, $data
        }
    }
    $self->_unlock();
    return $self->_filter_by_args(\@data_set, $args)
}








sub remove {
    my ($self, $object_name, $properties, $id) = @_;

    $self->_write_lock($object_name, $properties);
    my $dbh = $self->dbh($object_name, $properties) or return undef;
    delete $dbh->{ "!ID:" . $id };
    $self->_unlock();
    return 1
}




sub _dir {
    my ($self, $props) = @_;

    my $dir = $props->{datasource} || File::Spec->tmpdir();
    unless ( -e $dir ) {
        require File::Path;
        File::Path::mkpath($dir) or die $!
    }
    return $dir
}



sub _filename {
    my ($self, $object_name, $props) = @_;


    my $dir = $self->_dir($props);
    my $filename = lc $object_name;
    $filename    =~ s/\W+/_/g;

    return File::Spec->catfile($dir, $filename . '.dbm')
}







sub _read_lock {
    my ($self, $object_name, $props) = @_;

    my $filename = $self->_filename($object_name, $props) . '.lck';
    sysopen(LCK, $filename, O_RDONLY|O_CREAT, 0600) 
        or die "couldn't open/create $filename: $!";
    flock(LCK, LOCK_SH) or die "couldn't lock $filename: $!";
    $lock = \*LCK
}



sub _write_lock {
    my ($self, $object_name, $props) = @_;

    my $filename = $self->_filename($object_name, $props) . '.lck';
    sysopen(LCK, $filename, O_RDWR|O_CREAT, 0600)
        or die "couldn't open/create $filename: $!";
    flock(LCK, LOCK_EX) or die "couldn't lock $filename: $!";
    $lock = \*LCK
}



sub _unlock {
    my $self = shift;

    unless ( defined $lock ) {
        croak "Nothing to unlock"
    }
    close($lock) or die "couldn't unlock: $!";

    return 1
}







1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver::DBM - Base class for DBM-related pobject drivers

=head1 SYNOPSIS

    use Class::PObject::Driver::DBM;
    @ISA = ('Class::PObject::Driver::DBM');

    sub dbh {
        my ($self, $pobject_name, $properties) = @_;
        ...
    }

=head1 ABSTRACT

    Class::PObject::Driver::DBM is a base class for all the DBM-related
    pobject drivers. Class::PObject::Driver::DBM is a direct subclass of
    Class::PObject::Driver.

=head1 DESCRIPTION

Class::PObject::Driver::DBM is a direct subclass of Class::PObject::Driver, 
and provides all the necessary methods common for DBM-related disk access.

=head1 METHODS

Refer to L<Class::PObject::Driver|Class::PObject::Driver> for the details of all
the driver-specific methods. Class::PObject::Driver::DBM overrides C<save()>,
C<load()> and C<remove()> methods with the versions relevant to DBM-related
disk access.

=over 4

=item *

C<dbh($self, $pobject_name, \%properties)> - called whenever base methods
need database tied hash. DBM drivers should provide this method, which should
return a reference to a tied hash.

=item *

C<_filename($self, $pobject_name, \%properties)> - returns a name of the file
to connect to. It first looks for C<$properties->{datasource}> and if it exists,
uses the value as a directory name object file should be created in. If it's missing,
defaults to systems temporary folder.

It then returns a file name derived out of C<$pobject_name> inside this directory.

=item *

C<_read_lock($self, $pobject_name, \%properties)> - acquires a shared lock for the
object file.

=item *

C<_write_lock($self, $pobject_name, \%properties)> - acquires an exclusive lock for
the object file.

=item *

C<_unlock()> - unlocks existing lock

=back

=head1 SEE ALSO

L<Class::PObject::Driver>,
L<Class::PObject::Driver::DB_File>
L<Class::PObject::Driver::DBI>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>, http://author.handalak.com/

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
