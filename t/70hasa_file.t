

# $Id: 70hasa_file.t,v 1.3 2003/09/09 00:12:02 sherzodr Exp $

use strict;
use File::Spec;
use Class::PObject::Test::HAS_A;

my $t = new Class::PObject::Test::HAS_A(undef, File::Spec->catfile('data', 'has_a', 'file'));
$t->run();



