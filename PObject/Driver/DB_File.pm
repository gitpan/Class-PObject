package Class::PObject::Driver::DB_File;

use strict;
use vars ('$VERSION', '@ISA');
use Carp;
use DB_File;
use Class::PObject::Driver::DBM;

@ISA = ('Class::PObject::Driver::DBM');
$VERSION = '1.00';

sub dbh {
    my ($self, $object_name, $props) = @_;

    my $filename = $self->_filename($object_name, $props);
    my %dbh = ();
    unless ( tie %dbh, "DB_File", $filename, O_RDWR|O_CREAT, 0600 ) {
        $self->errstr("couldn't connect to '$filename': $!");
        return undef
    }

    return \%dbh
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver::DB_File - DB_File PObject driver

=head1 SYNOPSIS

    use Class::PObject;
    pobject Article => {
        columns => ['id', 'title', 'author', 'content'],
        driver  => 'DB_File',
        datasource => './data'
    };

=head1 DESCRIPTION

Class::PObject::Driver::DB_File is a direct subclass of
L<LClass::PObject::Driver::DBM|Class::PObject::Driver::DBM>.

=head1 METHODS

Class::PObject::Driver::DB_File only provides C<dbh()> method

=over 4

=item *

C<dbh($self, $pobject_name, \%properties)> -  returns a reference to a hash tied to a database.

=back

=head1 SEE ALSO

L<Class::PObject::Driver>
L<Class::PObject::Driver::DBM>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>, http://author.handalak.com/

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
