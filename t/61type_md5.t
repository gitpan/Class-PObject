# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 8;
BEGIN { 
	use_ok("Class::PObject::Type::MD5")
}

#########################

my $md5 = new Class::PObject::Type::MD5("geek");
ok($md5, "type created");
ok($md5->as_string eq '27dee4501f5da0e12be7ef16eb743e56', $md5->as_string);
ok($md5 eq 'geek', "'eq' working fine");

$md5 = undef;

$md5 = new Class::PObject::Type::MD5(undef, "args");
ok(ref $md5);
ok($md5->as_string ? 0 : 1);

$md5->value("27dee4501f5da0e12be7ef16eb743e56");
ok($md5->as_string);
ok($md5 eq "geek");
