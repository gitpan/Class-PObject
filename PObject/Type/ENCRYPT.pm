package Class::PObject::Type::ENCRYPT;

# $Id: ENCRYPT.pm,v 1.1 2003/08/27 20:36:55 sherzodr Exp $

use strict;
use vars ('$VERSION', '@ISA');
use Carp;
use Data::Dumper;
use Digest::MD5 ("md5_hex");
use base("Class::PObject::Type");

use overload (
	'eq'    => \&compare,
	fallback => 1
);

$VERSION = '0.01';



sub encode {
	my ($class, $value, $args) = @_;
	unless ( $value ) {
		return undef
	}
	$args ||= join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
	return crypt($value, $args)
}



sub compare {
	my ($self, $string) = @_;

	return crypt($string, $self->as_string) eq $self->as_string
}





1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Type::ENCRYPT - Defines ENCRYPT column type

=head1 DESCRIPTION

ISA L<Class::PObject::Type|Class::PObject::Type>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
