

# $Id: Makefile.PL,v 1.9 2003/08/23 10:36:22 sherzodr Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
  return <<'TAG';
realclean::
	$(RM_RF) data
TAG
}

WriteMakefile(
    NAME	       	=> 'Class::PObject',
    VERSION_FROM	=> 'PObject.pm',
    PREREQ_PM	  	=> {
	    'Storable'      => 0, 
	    'File::Spec'    => 0,
	    'IO::Dir'       => 0,
	    'Test::More'    => 0,
	    'Log::Agent'    => 0
    },
    ABSTRACT	    => "Framework for programming persistent objects",
    AUTHOR	        => 'Sherzod Ruzmetov <sherzodr@cpan.org>'
);

