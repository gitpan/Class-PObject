

# $Id: 01basic_file.t,v 1.5 2003/08/23 14:31:32 sherzodr Exp $

use File::Spec;
use Class::PObject::Test::Basic;

my $t = new Class::PObject::Test::Basic('file', File::Spec->catfile('data', 'file'));
$t->run();




