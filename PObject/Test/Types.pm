package Class::PObject::Test::Types;

use strict;
#use diagnostics;
use Test::More;
use vars ('$VERSION', '@ISA');

BEGIN {
    plan(tests => 40);
    use_ok("Class::PObject");
    use_ok("Class::PObject::Test");
    use_ok("Class::PObject::Type");
}

@ISA = ('Class::PObject::Test');
$VERSION = '1.02';


sub run {
    my $self = shift;

    pobject User => {
        columns     => ['id', 'name', 'login', 'psswd', 'activation_key'],
        driver      => $self->{driver},
        datasource  => $self->{datasource},
        serializer  => 'storable',
        tmap        => {
            login       => 'CHAR(18)',
            psswd       => 'ENCRYPT',
            name        => 'VARCHAR(40)',
            id          => 'INTEGER',
            activation_key => 'MD5'
        }
    };
    ok(1);

    ################
    #
    # Creating a new user
    #
    my $u = new User();
    ok($u);
    $u->name("Sherzod Ruzmetov");
    $u->login("sherzodr");
    $u->psswd("marley01");
    $u->activation_key("geek");

    print $u->dump;
    #exit(0);

    ################
    #
    # checking integrity of data before saving to disk
    #
    ok($u->name            eq "Sherzod Ruzmetov");
    ok($u->login        eq "sherzodr");
    ok($u->psswd        eq "marley01", $u->psswd);
    ok($u->activation_key eq "geek", $u->activation_key);

    ok(ref($u->name)    eq 'VARCHAR');
    ok(ref($u->login)    eq 'CHAR');
    ok(ref($u->id)        eq 'INTEGER');
    ok(ref($u->psswd)    eq 'ENCRYPT');
    ok(ref($u->activation_key) eq 'MD5');

    #print $u->dump;

    # let's check if we can assign objects directly
    my $name = VARCHAR->new(id=>"Sherzod Ruzmetov (e)", args=>40);
    ok($name, $name);
    $u->name( $name );
    ok($u->name            eq "Sherzod Ruzmetov (e)", $u->name);
    ok(ref($u->name)    eq "VARCHAR", ref($u->name));

    #print $u->dump;

    $u->name( "Sherzod Ruzmetov" );
    ok($u->name            eq "Sherzod Ruzmetov", $u->name);
    ok(ref($u->name)    eq "VARCHAR", ref($u->name));

    #print $u->dump;

    ok(my $id = $u->save, $u->errstr);

    $u =  undef;

    $u = User->load($id);
    ok($u);

    #print $u->dump;

    ################
    #
    # checking integrity of data after loaded from disk
    #
    ok($u->name            eq "Sherzod Ruzmetov");
    ok($u->login        eq "sherzodr");
    ok($u->psswd        eq "marley01", $u->psswd);

    ok(ref($u->name)    eq 'VARCHAR');
    ok(ref($u->login)    eq 'CHAR');
    ok(ref($u->id)        eq 'INTEGER');
    ok(ref($u->psswd)    eq 'ENCRYPT');

    ################
    #
    # Updating the values again
    #
    $u->name("Sherzod Ruzmetov (e)");
    $u->psswd("marley02)");

    ok($u->psswd        eq "marley02", $u->psswd);
    ok($u->name            eq "Sherzod Ruzmetov (e)");
    ok($u->activation_key eq "geek");
    ok(ref($u->psswd)    eq 'ENCRYPT');
    ok(ref($u->activation_key), 'MD5');
    ok($u->save == $id, $u->errstr);


    ################
    #
    # Checking load(\%terms, undef) syntax
    #
    
    $u = User->load({login=>'sherzodr'});
    ok($u);
    ok($u->psswd        eq "marley02");
    ok($u->activation_key eq "geek");

    ok(User->count == 1);
    ok(User->remove_all());
    ok(User->count == 0)
}






package VARCHAR;
use vars ('@ISA');
use Class::PObject::Type::VARCHAR;
@ISA = ("Class::PObject::Type::VARCHAR");


1;
__END__

=head1 NAME

Class::PObject::Test::Types - Class::PObject't types test suits

=head1 SYNOPSIS

    # inside t/*.t files:
    use Class::PObject::Test::Types;
    $t = new Class::PObject::Test::Types($drivername, $datasource);
    $t->run() # running the tests

=head1 DESCRIPTION

F<Types.pm> is a test suit similar to L<Class::PObject::Test::Basic|Class::PObject::Test::Basic>,
but concentrates on column type specification

=head1 SEE ALSO

L<Class::PObject::Test::Basic>,
L<Class::PObject::Test::HAS_A>

=head1 COPYRIGHT AND LICENSE

For author and copyright information refer to Class::PObject's L<online manual|Class::PObject>.

=cut
