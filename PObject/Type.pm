package Class::PObject::Type;

# $Id: Type.pm,v 1.2 2003/08/28 16:32:24 sherzodr Exp $

use strict;
use vars ('$VERSION');
use overload (
	'""'    => \&as_string
);

$VERSION = '0.01';

sub new {
	my $class = shift;
	$class = ref($class) || $class;

	my $self = {
		value  => undef,
		args   => $_[1] || undef
	};
	bless $self, $class;
	$self->{value} = $self->encode(@_);
	return  $self
}



sub encode {
	my ($self, $value, $args) = @_;

	return $value
}


sub as_string {
	my $self = shift;

	return $self->{value} || ""
}




sub value {
	my ($self, $value) = @_;

	$self->{value} = $value
}


sub DESTROY { }





sub dump {
	my $self = shift;

	require Data::Dumper;
	my $d = new Data::Dumper([$self], [ref $self]);
	return $d->Dump
}









1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Type - Class::PObject's column types specs

=head1 DESCRIPTION

Comming soon...

=head1 SEE ALSO

L<Class::PObject::Type::INTEGER>,
L<Class::PObject::Type::VARCHAR>,
L<Class::PObject::Type::ENCRYPT>,
L<Class::PObject::Type::MD5>,
L<Class::PObject::Type::SHA1>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
