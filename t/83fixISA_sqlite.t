

# $Id: 83fixISA_sqlite.t,v 1.1.2.1 2004/05/19 22:42:42 sherzodr Exp $

use File::Spec;
use Class::PObject::Test::ISA;

my $t = new Class::PObject::Test::ISA('sqlite', File::Spec->catfile('data', 'isa', 'sqlite', 'data.db'));
$t->run();

