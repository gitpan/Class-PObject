# $Id: 62types_csv.t,v 1.1.2.1 2003/09/05 22:24:36 sherzodr Exp $

#########################

use strict;
use File::Spec;
use Class::PObject::Test::Types;

#########################

my $t = new Class::PObject::Test::Types('csv', {Dir=>File::Spec->catfile('data', 'types', 'csv')});
$t->run();

