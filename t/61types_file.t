

# $Id$

use strict;
use File::Spec;
use Class::PObject::Test::Types;

my $t = new Class::PObject::Test::Types(undef, File::Spec->catfile('data', 'types', 'file'));
$t->run();

