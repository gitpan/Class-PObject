

# $Id: 62types_csv.t,v 1.3 2003/09/09 00:12:02 sherzodr Exp $

use strict;
use File::Spec;
use Class::PObject::Test::Types;

my $t = new Class::PObject::Test::Types('csv', {Dir=>File::Spec->catfile('data', 'types', 'csv')});
$t->run();

