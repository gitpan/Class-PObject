

# $Id: 01basic_file.t,v 1.4 2003/08/23 13:15:13 sherzodr Exp $

use Class::PObject::Test::Basic;

my $t = new Class::PObject::Test::Basic('file', 'data');
$t->run();

