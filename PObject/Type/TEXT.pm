package Class::PObject::Type::TEXT;

# $Id: TEXT.pm,v 1.1.2.4 2003/09/06 14:00:51 sherzodr Exp $

use strict;
#use diagnostics;
use vars ('$VERSION', '@ISA');
use Class::PObject::Type;
use overload (
    '""' => sub { $_[0]->id },
    bool => sub { $_[0]->id ? 1 : 0 },
    fallback => 1,
);


@ISA = ("Class::PObject::Type");

$VERSION = '1.01';


1;
__END__

=head1 NAME

Class::PObject::Type::TEXT - Defines TEXT column type

=head1 DESCRIPTION

ISA L<Class::PObject::Type|Class::PObject::Type>

=head1 COPYRIGHT AND LICENSE

For author and copyright information refer to Class::PObject's L<online manual|Class::PObject>.

=cut
