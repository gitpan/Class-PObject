
# $Id: 70hasa_file.t,v 1.1.2.1 2003/09/06 09:57:08 sherzodr Exp $

use File::Spec;
use Class::PObject::Test::HAS_A;

my $t = new Class::PObject::Test::HAS_A(undef, File::Spec->catfile('data', 'has_a', 'file'));
$t->run();



