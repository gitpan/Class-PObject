package Class::PObject::Test::Basic;

use strict;
use warnings;
use Test::More;
use Class::PObject;
use Class::PObject::Test;

use vars ('$VERSION', '@ISA');

@ISA = ('Class::PObject::Test');
$VERSION = '1.00';


BEGIN {
    plan(tests => 137);
    use_ok("Class::PObject")
}


sub run {
    my $self = shift;

    pobject PO::Author => {
        columns     => ['id', 'name', 'url', 'email'],
        driver      => $self->{driver},
        datasource  => $self->{datasource}
    };
    ok(1);


    pobject PO::Article => {
        columns     => ['id', 'title', 'author', 'content', 'rating'],
        driver      => $self->{driver},
        datasource  => $self->{datasource}
    };
    ok(1);

    ####################
    #
    # 2. Testing pobject_init() method
    #
    {
        package PO::Author;
        use Test::More;
        sub pobject_init {
            ok(ref($_[0]) eq 'PO::Author')
        }

        package PO::Article;
        use Test::More;
        sub pobject_init {
            ok(ref($_[0]) eq 'PO::Article')
        }
    }

    ####################
    #
    # 3. Creating new objects
    #
    my $author1 = new PO::Author();
    ok($author1);

    my $author2 = new PO::Author();
    ok($author2);

    my $author3 = new PO::Author(name=>"Geek", email=>'sherzodr@cpan.org');
    ok($author3);



    my $article1 = new PO::Article();
    ok($article1);

    my $article2 = new PO::Article();
    ok($article2);

    my $article3 = new PO::Article();
    ok($article3);

    ####################
    #
    # 4. Test columns(), __props() and __driver() methods
    #
    ok(ref($author1) eq 'PO::Author');
    ok(ref($author1->columns) eq 'HASH');
    ok(ref($author1->__props) eq 'HASH');
    ok(ref($author1->__driver) eq 'Class::PObject::Driver::' . $self->{driver});

    ####################
    #
    # 5. Test if accessor methods have been created successfully
    #
    ok($author1->can('id') && $author2->can('name') && $author3->can('email'));
    ok($author1->name ? 0 : 1);

    ok($article1->can('id') && $article2->can('title') && $article3->can('author'));

    ####################
    #
    # 6. Checking if accessor methods function as expected
    #
    $author1->name("Sherzod Ruzmetov");
    $author1->url('http://author.handalak.com/');
    $author1->email('sherzodr@cpan.org');

    ok($author1->name eq "Sherzod Ruzmetov");
    ok($author1->email eq 'sherzodr@cpan.org');
    
    $author1->name(undef);

    ok($author1->name ? 0 : 1);
    ok($author1->{_is_new} == 1);

    $author2->name("Hilola Nasyrova");
    $author2->url('http://hilola.handalak.com/');
    $author2->email('some@email.com');

    ok($author2->name eq "Hilola Nasyrova");
    ok($author2->email eq 'some@email.com');
    ok($author2->{_is_new} == 1);

    $article1->title("Class::PObject rules!");
    $article1->content("This is the article about Class::PObject and how great this library is");
    $article1->rating(0);

    ok($article1->title eq "Class::PObject rules!");
    ok($article1->rating == 0);


    ####################
    #
    # 7. Testing save()
    #
    my $author1_id = undef;
    ok($author1_id = $author1->save);

    my $author2_id = undef;
    ok($author2_id = $author2->save);

    my $author3_id = undef;
    ok($author3_id = $author3->save);

    $article1->author($author1_id);

    my $article1_id = undef;
    ok($article1_id = $article1->save);

    undef($author1);
    undef($author2);
    undef($article1);

    ####################
    #
    # 8. Testing load() and integrity of the object
    #

    $article1 = PO::Article->load($article1_id);
    ok($article1);

    ok($article1->title eq "Class::PObject rules!");
    ok(defined $article1->rating);
    ok($article1->rating == 0);

    $author1 = PO::Author->load($article1->author);
    ok($author1);

    ok($author1->{_is_new} == 0);
    ok($author1->email eq 'sherzodr@cpan.org');
    ok($author1->name ? 0 : 1);
    ok($author1->url eq 'http://author.handalak.com/');

    ####################
    #
    # 9. Checking if object properties can be updated
    #
    $author1->url('http://sherzodr.handalak.com/');
    $author1->name("Sherzod Ruzmetov");
    ok($author1->save);

    $author1 = undef;
    $author1 = PO::Author->load($author1_id);
    ok($author1);

    ok($author1->name eq "Sherzod Ruzmetov");
    ok($author1->email eq "sherzodr\@cpan.org");
    ok($author1->url   eq 'http://sherzodr.handalak.com/');

    ####################
    #
    # 10. load()ing pobject in array context
    #
    my @authors = PO::Author->load();
    ok(@authors == 3);
    for ( @authors ) {
        printf("[%d] - %s <%s>\n", $_->id, $_->name, $_->email)
    }
    @authors = undef;

    ####################
    #
    # 11. Loading object(s) in array context with terms
    #
    @authors = PO::Author->load({id=>$author1_id});
    for ( @authors ) {
        ok($_->name eq "Sherzod Ruzmetov");
        ok($_->email eq "sherzodr\@cpan.org")
    }


    ####################
    #
    # 12. Checking count()
    #
    ok(PO::Author->count == 3);

    ok(PO::Author->count({name=>"Doesn't exist!"}) == 0);

    ok(PO::Author->count({email=>'sherzodr@cpan.org', name=>"Sherzod Ruzmetov"}) == 1);

    ok(PO::Author->count({email=>'sherzodr@cpan.org'}) == 2);


    ####################
    #
    # 13. Checking more complex terms
    #
    @authors = PO::Author->load({email=>'sherzodr@cpan.org', name=>"Sherzod Ruzmetov"});
    ok(@authors == 1);
    ok($authors[0]->id == $author1_id);
    ok($authors[0]->url eq 'http://sherzodr.handalak.com/', $authors[0]->url);

    @authors = undef;
    @authors = PO::Author->load({url=>'http://hilola.handalak.com/', name=>"Bogus"});
    ok(@authors == 0);


    @authors = PO::Author->load({url=>'http://hilola.handalak.com/'});
    ok(@authors == 1);


    ####################
    #
    # 14. Checking load(undef, \%args) syntax
    #
    @authors = PO::Author->load(undef, {'sort' => 'name'});
    ok(@authors == 3);

    ok($authors[0]->name eq "Geek");
    ok($authors[1]->name eq "Hilola Nasyrova");
    ok($authors[2]->name eq "Sherzod Ruzmetov");





    @authors = ();
    @authors = PO::Author->load(undef, {'sort' => 'email'});
    ok(@authors == 3);

    ok($authors[0]->email eq 'sherzodr@cpan.org');
    ok($authors[1]->email eq 'sherzodr@cpan.org');





    # same as above, but with explicit 'direction'
    @authors = ();
    @authors = PO::Author->load(undef, {'sort' => 'email', direction=>'asc'});
    ok(@authors == 3);

    ok($authors[0]->email eq 'sherzodr@cpan.org');
    ok($authors[1]->email eq 'sherzodr@cpan.org');
    ok($authors[2]->email eq 'some@email.com');







    @authors = ();
    @authors = PO::Author->load(undef, {'sort'=>'name', direction=>'desc'});
    ok(@authors == 3);

    ok($authors[0]->name eq "Sherzod Ruzmetov");
    ok($authors[1]->name eq "Hilola Nasyrova");
    ok($authors[2]->name eq "Geek");






    @authors = ();
    @authors = PO::Author->load(undef, {'sort'=>'id', direction=>'desc', limit=>1});
    ok(@authors == 1);

    ok($authors[0]->name eq "Geek");



    # same as above, but with explicit 'offset'
    @authors = ();
    @authors = PO::Author->load(undef, {'sort'=>'id', direction=>'desc', limit=>1, offset=>0});
    ok(@authors == 1);

    ok($authors[0]->name eq "Geek");



    @authors = ();
    @authors = PO::Author->load(undef, {'sort'=>'id', direction=>'desc', offset=>1, limit=>1});
    ok(@authors == 1);

    ok($authors[0]->name eq "Hilola Nasyrova");



    $author1 = PO::Author->load(undef, {'sort'=>'id', direction=>'desc', limit=>1});
    ok($author1);
    ok($author1->name eq "Geek");



    ####################
    #
    # 15. Checking load(\%terms, \%args) syntax
    #
    @authors = ();
    @authors = PO::Author->load({name=>"Sherzod Ruzmetov"}, {'sort'=>'name'});
    ok(@authors == 1);
    ok($authors[0]->email eq 'sherzodr@cpan.org');







    @authors = ();
    @authors = PO::Author->load({email=>'sherzodr@cpan.org'}, {'sort'=>'name'});
    ok(@authors == 2);

    ok($authors[0]->name eq "Geek");
    ok($authors[1]->name eq "Sherzod Ruzmetov");




    @authors = ();
    @authors = PO::Author->load({email=>'sherzodr@cpan.org'}, {'sort'=>'name', direction=>'desc'});
    ok(@authors == 2);

    ok($authors[0]->name eq "Sherzod Ruzmetov");
    ok($authors[1]->name eq "Geek");




    @authors = PO::Author->load({email=>'sherzodr@cpan.org'}, {'sort'=>'name', direction=>'asc', limit=>1});
    ok(@authors == 1);

    ok($authors[0]->name eq "Geek");



    $author3 = undef;
    $author3 = PO::Author->load({email=>'sherzodr@cpan.org'}, {'sort'=>'name', direction=>'asc', limit=>1});
    ok($author3);

    ok($author3->name eq "Geek");


    @authors = PO::Author->load({email=>'sherzodr@cpan.org'}, {'sort'=>'name', limit=>1, offset=>1});
    ok(@authors == 1);

    ok($authors[0]->name eq "Sherzod Ruzmetov");









    ####################
    #
    # Cleaning up all the objects so that for the next 'make test'
    # can start with brand new scratch board
    #

    ok(PO::Author->remove_all({name=>"Geek"}));
    ok(PO::Author->count == 2);
    ok(PO::Author->remove_all);
    ok(PO::Author->count == 0);

    ok(PO::Article->remove_all);
    ok(PO::Article->count == 0)
    #ok(1);
    #ok(1);
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
