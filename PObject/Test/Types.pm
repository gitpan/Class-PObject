package Class::PObject::Test::Basic;

use strict;
use Test::More;
use Class::PObject;
use Class::PObject::Test;

use vars ('$VERSION', '@ISA');

@ISA = ('Class::PObject::Test');
$VERSION = '1.00';


BEGIN {
    plan(tests => 2);
    use_ok("Class::PObject")
}


sub run {
    my $self = shift;

	pobject Article => {
		columns			=> ['id', 'title', 'author', 'content'],
		driver			=> $self->{driver},
		datasource		=> $self->{datasource},
		tmap => {
			id      => 'INTEGER',
			title   => 'VARCHAR(256)',
			author	=> 'Author',
			content => 'TEXT'
		}
	};
	pubject Author => {
		columns => ['id', 'name', 'login', 'psswd', 'email'],
		driver  => $self->{driver},
		datasource => $self->{datasource},
		tmap => {
			psswd => 'ENCRYPT'
		}
	};	
	ok(1);
}









1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Test::Basic - Class::PObject's basic test suit

=head1 SYNOPSIS

    # inside t/*.t files:
    use Class::PObject::Test::Basic;
    $t = new Class::PObject::Test::Basic($drivername, $datasource);
    $t->run() # running the tests

=head1 ABSTRACT

    Class::PObject::Test::Basic is a subclass of Class::PObject::Test::Basic,
    and is used for running basic tests for a specific driver.

=head1 DESCRIPTION

This library is particularly useful for Class::PObject driver authors. It provides
a convenient way of testing your newly created PObject driver to see if it functions
properly, as well as helps you to write test scripts with literally couple of lines
of code.

Class::PObject::Test::Basic is a subclass of L<Class::PObject::Test>.

=head1 NATURE  OF TESTS

Class::POBject::Test::Basic runs tests to check following aspects of the driver:

=over 4

=item *

C<pobject> declarations.

=item *

Creating and initializing pobject instances

=item *

Proper functionality of the accessor methods and integrity of in-memory data

=item *

Synchronization of in-memory data into disk

=item *

If basic load() performs as expected, in both array and scalar context.

=item *

Checking the integrity of synchronized disk data

=item *

Checking for count() - both simple syntax, and count(\%terms) syntax.

=item *

Checking different combinations of C<load(undef, \%args)>, C<load(\%terms, undef)>,
C<load(\%terms, \%args)>

=item *

Checking if objects can be removed off the disk successfully

=back

In addition to the above tests, Class::PObject::Test::Basic also address such issues
as I<multiple instances of the same object> as well as I<multiple classes and multiple objects>
cases, which have been major sources for bugs for L<Class::PObject> drivers.

=head1 SEE ALSO

L<Class::PObject::Test>, L<Class::PObject>, L<Class::PObject::Driver>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>, http://author.handalak.com/

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
