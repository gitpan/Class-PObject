package Class::PObject::Test::HAS_A;

use strict;
#use diagnostics;
use Test::More;
use Data::Dumper;
use vars ('$VERSION', '@ISA');

BEGIN {
    plan(tests => 27);
    use_ok("Class::PObject");
    use_ok("Class::PObject::Test")
}

@ISA = ('Class::PObject::Test');
$VERSION = '1.00';


sub run {
    my $self = shift;

    pobject 'PO::Author' => {
        columns        => ['id', 'name'],
        driver      => $self->{driver},
        datasource  => $self->{datasource},
        serializer  => 'storable'
    };
    ok(1);

    pobject 'PO::Article' => {
        columns        => ['id', 'title', 'author'],
        driver        => $self->{driver},
        datasource    => $self->{datasource},
        serializer    => 'storable',
        tmap        => {
            author        => 'PO::Author'
        }
    };
    ok(1);

    ################
    #
    # Creating a new Author
    #
    my $author = new PO::Author();
    $author->name("Sherzod Ruzmetov");
    ok($author->name eq "Sherzod Ruzmetov");
    ok(my $author_id = $author->save, $author->errstr);

    $author = undef;

    ################
    #
    # Creating new article
    #
    my $article = new PO::Article();
    $article->title("Class::PObject now supports type-mapping");

    $author = PO::Author->load($author_id);
    #print $article->dump;
    $article->author( $author );
    #print $article->dump;
    #print $author->dump;

    ok($article->author->name eq "Sherzod Ruzmetov",    $article->author->name);
    ok(ref($article->author) eq "PO::Author",                ref($article->author));
    ok(my $article_id = $article->save(),                $article->errstr );

    #print $article->dump;

    $article = $author = undef;

    $article = PO::Article->load($article_id);
    ok($article);

    #print $article->dump;

    $author = $article->author;
    ok($article->title eq "Class::PObject now supports type-mapping", $article->title);
    ok($author->name eq "Sherzod Ruzmetov",    $article->author->name);
    ok(ref ($author) eq "PO::Author",                ref($article->author));

    ok($article->save == $article_id, $article->errstr);
    
    #print $article->dump;
    $article = undef;

    $article = PO::Article->load({author=>$author});
    ok($article);

    #print $article->dump;

    ok($article->title eq "Class::PObject now supports type-mapping", $article->title);
    ok($article->author->name eq "Sherzod Ruzmetov",    $article->author->name);
    ok(ref($article->author) eq "PO::Author",                ref($article->author));

    ok($article->save == $article_id, $article->errstr);

    $article = undef;

    my $result = PO::Article->fetch({author=>$author});
    ok($article = $result->next);

    #print $article->dump;

    ok($author = $article->author);
    #print $article->dump;
    ok($article->title eq "Class::PObject now supports type-mapping", $article->title);
    ok($author->name eq "Sherzod Ruzmetov",    $article->author->name);
    ok(ref($author) eq "PO::Author",                ref($article->author));

    print Dumper($article->columns);

    ok(PO::Article->count({author=>$author}) == 1);
    ok(PO::Article->remove_all);
    ok(PO::Article->count({author=>$author}) == 0);
}

1;
__END__

=head1 NAME

Class::PObject::Test::HAS_A - Class::PObject't has-a relationship test suit

=head1 SYNOPSIS

    # inside t/*.t files:
    use Class::PObject::Test::HAS_A;
    $t = new Class::PObject::Test::HAS_A($drivername, $datasource);
    $t->run() # running the tests

=head1 DESCRIPTION

F<HAS_A.pm> is a test suit similar to L<Class::PObject::Test::Basic|Class::PObject::Test::Basic>,
but concentrates on objects' has-a relationships - extended type-mapping feature.

=head1 SEE ALSO

L<Class::PObject::Test::Basic>,
L<Class::PObject::Test::Types>

=head1 COPYRIGHT AND LICENSE

For author and copyright information refer to Class::PObject's L<online manual|Class::PObject>.

=cut
