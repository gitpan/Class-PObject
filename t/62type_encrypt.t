# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 8;
BEGIN { 
	use_ok("Class::PObject::Type::ENCRYPT")
}

#########################

my $md5 = new Class::PObject::Type::ENCRYPT("geek");
ok(ref $md5);

print $md5->dump;

my $crypted = $md5->as_string;

ok($md5 eq "geek", "'geek' eq '$crypted'" );
ok($md5->as_string eq $crypted);

$md5 = undef;
$md5 = new Class::PObject::Type::ENCRYPT();
ok( ref $md5 );

print $md5->dump;

ok( $md5->as_string ? 0 : 1);

$md5->value($crypted);

print $md5->dump;

ok($md5 eq "geek");

ok($md5->as_string eq $crypted)
