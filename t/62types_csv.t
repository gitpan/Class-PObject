

# $Id$

use strict;
use File::Spec;
use Class::PObject::Test::Types;

my $t = new Class::PObject::Test::Types('csv', {Dir=>File::Spec->catfile('data', 'types', 'csv')});
$t->run();

