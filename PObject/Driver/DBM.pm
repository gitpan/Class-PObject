package Class::PObject::Driver::DBM;

# $Id: DBM.pm,v 1.3 2003/08/24 20:51:25 sherzodr Exp $

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
    
    my (undef, $dbh, $unlock) = $self->dbh($object_name, $properties, 'w') or return undef;
    unless ( $columns->{id} ) {
        my $lastid = $dbh->{_lastid} || 0;
        $columns->{id} = ++$dbh->{_lastid}
    }
    $dbh->{ "!ID:" . $columns->{id} } = $self->freeze($columns);
    $unlock->();
    return $columns->{id}
}



sub load {
    my ($self, $object_name, $properties, $terms, $args) = @_;

    my (undef, $dbh, $unlock) = $self->dbh($object_name, $properties) or return undef;
    if ( $terms && (ref($terms) ne 'HASH') && ($terms =~ /^\d+$/) ) {
        return [$self->thaw( $dbh->{"!ID:" . $terms} )]
    }
    my @data_set = ();
    my $n = 0;
    while ( my ($k, $v) = each %$dbh ) {
        if ( $args && $args->{limit} && !$args->{offset} && !$args->{sort} ) {
            $n++ == $args->{limit} and last
        }
        $k =~ /!ID:/ or next;
        my $data = $self->thaw( $v );
        if ( $self->_matches_terms($data, $terms) ) {
            push @data_set, $data
        }
    }
    $unlock->();
    return $self->_filter_by_args(\@data_set, $args)
}








sub remove {
    my ($self, $object_name, $properties, $id) = @_;

    
    my (undef, $dbh, $unlock) = $self->dbh($object_name, $properties, 'w') or return undef;
    delete $dbh->{ "!ID:" . $id };
    $unlock->();
    return 1
}










sub _lock {
    my $self = shift;
    my ($file, $type) = @_;
    
    $file    .= '.lck';
    my $lock_flags = $type eq 'w' ? LOCK_EX : LOCK_SH;

    require Symbol;
    my $lock_h = Symbol::gensym();
    unless ( sysopen($lock_h, $file, O_RDWR|O_CREAT, 0666) ) {
        $self->errstr("couldn't create/open '$file': $!");
        return undef
    }
    unless (flock($lock_h, $lock_flags)) {
        $self->errstr("couldn't lock '$file': $!");
        close($lock_h);
        return undef
    }
    return sub { 
        close($lock_h);
        unlink $file
    }
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

C<dbh($self, $pobject_name, \%properties, $lock_type)> - called whenever base methods
need database tied hash. DBM drivers should provide this method, which should
return an array of elements, namely C<$DB> - an DBM object, usually returned from
C<tie()> or C<tied()> functions; C<$dbh> - a hash tied to database; C<$unlock> - 
an action required for unlocking the database. C<$unlock> should be a reference 
to a subroutine, which when called should release the lock.

Currently base methods ignore C<$DB>, but it may change in the future.

=item *

C<_filename($self, $pobject_name, \%properties)> - returns a name of the file
to connect to. It first looks for C<$properties->{datasource}> and if it exists,
uses the value as a directory name object file should be created in. If it's missing,
defaults to systems temporary folder.

It then returns a file name derived out of C<$pobject_name> inside this directory.

=item *

C<_lock($file, $filename, $lock_type)> - acquires either shared or exclusive lock depending
on the C<$lock_type>, which can be either of I<w> or I<r>.

Returns a reference to an action (subroutine), which perform unlocking for this particular
lock. On failure returns undef. C<_lock()> is usually called from within C<dbh()>, and return
value is returned together with database hadnles.

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
