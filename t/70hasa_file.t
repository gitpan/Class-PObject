

# $Id$

use strict;
use File::Spec;
use Class::PObject::Test::HAS_A;

my $t = new Class::PObject::Test::HAS_A(undef, File::Spec->catfile('data', 'has_a', 'file'));
$t->run();



