

# $Id: 80fixISA_file.t,v 1.1.2.1 2004/05/19 22:42:42 sherzodr Exp $

use File::Spec;
use Class::PObject::Test::ISA;

my $t = new Class::PObject::Test::ISA('file', File::Spec->catfile('data', 'isa', 'file'));
$t->run();

