package Class::PObject::Type::MD5;

# $Id: MD5.pm,v 1.1 2003/08/27 20:36:55 sherzodr Exp $

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
	return md5_hex($value)
}




sub compare {
	my ($self, $string) = @_;

	return $self->{value} eq $self->encode($string)
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Type::MD5 - Defines MD5 column type

=head1 DESCRIPTION

ISA L<Class::PObject::Type|Class::PObject::Type>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
