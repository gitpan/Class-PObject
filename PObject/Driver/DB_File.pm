package Class::PObject::Driver::DB_File;

use strict;
use vars ('$VERSION', '@ISA');
use Carp;
use DB_File;
use Class::PObject::Driver::DBM;

@ISA = ('Class::PObject::Driver::DBM');

$VERSION = '2.00';

sub dbh {
    my ($self, $object_name, $props, $lock_type) = @_;

    my $filename = $self->_filename($object_name, $props);
    my ($DB, %dbh, $unlock);
    my $unlock = $self->_lock($filename, $lock_type||'r') or return undef;
    unless ( $DB = tie %dbh, "DB_File", $filename, O_RDWR|O_CREAT, 0600 ) {
        $self->errstr("couldn't connect to '$filename': $!");
        return undef
    }

    return ($DB, \%dbh, $unlock)
}




sub _filename {
    my ($self, $object_name, $props) = @_;


    my $dir = $self->_dir($props);
    my $filename = lc $object_name;
    $filename    =~ s/\W+/_/g;

    return File::Spec->catfile($dir, $filename . '.dbm')
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
