package Class::PObject::Driver::DBM;

# $Id: DBM.pm,v 1.1 2003/08/23 13:15:12 sherzodr Exp $

use strict;
use Carp;
use Class::PObject::Driver;
use File::Spec;
use vars ('$VERSION', '@ISA');

@ISA = ('Class::PObject::Driver');

$VERSION = '1.00';


sub save {
    my ($self, $object_name, $properties, $columns) = @_;

    my $dbh = $self->dbh($object_name, $properties) or return undef;

    unless ( $columns->{id} ) {
        my $lastid = $dbh->{_lastid} || 0;
        $columns->{id} = ++$dbh->{_lastid}
    }

    $dbh->{ "!ID:" . $columns->{id} } = $self->freeze($columns);
    return $columns->{id}
}



sub load {
    my ($self, $object_name, $properties, $terms, $args) = @_;

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
    return $self->_filter_by_args(\@data_set, $args)
}








sub remove {
    my ($self, $object_name, $properties, $id) = @_;

    my $dbh = $self->dbh($object_name, $properties) or return undef;
    return delete $dbh->{ "!ID:" . $id }
}






sub _filename {
    my ($self, $object_name, $props) = @_;

    my $dir = $props->{datasource} || File::Spec->tmpdir();
    unless ( -e $dir ) {
        require File::Path;
        File::Path::mkpath($dir) or die $!
    }

    my $filename = lc $object_name;
    $filename    =~ s/\W+/_/g;

    return File::Spec->catfile($dir, $filename . '.dbm')
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
