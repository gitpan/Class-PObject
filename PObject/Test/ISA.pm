package Class::PObject::Test::ISA;

# $Id: ISA.pm,v 1.1.2.2 2004/05/20 06:53:53 sherzodr Exp $

use strict;
#use diagnostics;
use Test::More tests => 19;
use Class::PObject;
use Data::Dumper;
require Class::PObject::Test;
use vars ('$VERSION', '@ISA');

@ISA = ('Class::PObject::Test');
$VERSION = '1.01';

use_ok("Class::PObject");


sub run {
    my $self = shift;

    {
        package PO::Parent;
        Class::PObject::pobject  {
            columns => ['id', 'data'],
            driver  => $self->{driver},
            datasource => $self->{datasource}
        };

        sub is_parent { 1 }
    }

    {
        package PO::Child;
        @PO::Child::ISA = ("PO::Parent");

#        sub __props {
#            return $PO::Parent::props;
#        }

        sub is_child { 1 }

    }


    my $child = PO::Child->new();
    ok(defined $child);

    # let's check the inheritance tree
    ok($child->UNIVERSAL::isa("PO::Child"));
    ok($child->UNIVERSAL::isa("PO::Parent"));
    ok($child->UNIVERSAL::isa("Class::PObject::Template"));

    ok($child->is_child == 1);
    ok($child->is_parent == 1);

    # PO::Child should also have access to PO::Parent->id() and PO::Parent->data()
    # methods
    ok($child->UNIVERSAL::can("id"));
    ok($child->UNIVERSAL::can("data"));

    $child->data("check");

    ok($child->data() eq "check");

    my $new_id = $child->save();
    ok($new_id);

    $child = undef;

    ok(PO::Child->count == 1);

    #
    #  now we're loading previously stored object
    #
    my $child_1 = PO::Child->load( $new_id );
    ok(defined $child_1);

    ok($child_1->id == $new_id);
    ok($child_1->data eq 'check');

    ok($child_1->UNIVERSAL::isa("PO::Child"));
    ok($child_1->UNIVERSAL::isa("PO::Parent"));

    #
    # removing all the data
    #
    ok(PO::Child->remove_all);
    ok(PO::Child->count() == 0);
}









1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Test::ISA - Class::PObject's @ISA-related test suit

=head1 SYNOPSIS

    # inside t/*.t files:
    use Class::PObject::Test::ISA;
    $t = new Class::PObject::Test::ISA($drivername, $datasource);
    $t->run() # running the tests

=head1 DESCRIPTION

=head1 NATURE  OF TESTS

=head1 SEE ALSO

L<Class::PObject::Test::Basic>,
L<Class::PObject::Test::Types>,
L<Class::PObject::Test::HAS_A>

=head1 COPYRIGHT AND LICENSE

For author and copyright information refer to Class::PObject's L<online manual|Class::PObject/"COPYRIGHT AND LICENSE">.

=cut
