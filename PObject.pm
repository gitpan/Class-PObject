package Class::PObject;

# $Id: PObject.pm,v 1.28 2003/08/23 13:17:10 sherzodr Exp $

use strict;
use Log::Agent;
use vars qw($VERSION $revision);

$VERSION    = '2.00_02';
($revision) = '$Revision: 1.28 $' =~ m/Revision:\s*(\S+)/;

# configuring Log::Agent
logconfig(-level=>$ENV{POBJECT_DEBUG} || 0, -caller=>[-display=>'($sub/$line)']);

# Preloaded methods go here.

sub import {
    my $class       = shift;
    my $caller_pkg  = (caller)[0];

    unless ( @_ ) {
        no strict 'refs';
        *{ "$caller_pkg\::pobject" } = \&{ "$class\::pobject" };
        return 1
    }
    require Exporter;
    return $class->Exporter::import(@_)
}

sub pobject {
    my ($class, $props);

    # are we given explicit class name to be created in?
    if ( @_ == 2 ) {
        ($class, $props) = @_;
        logtrc 1, "pobject %s => %s", $class, $props
    }
    # Is class name assumed to be the current caller's package?
    elsif ( $_[0] && (ref($_[0]) eq 'HASH') ) {
        $props = $_[0];
        $class = (caller())[0];
        logtrc 1, "pobject ('%s'), %s", $class, $props
    }
    # otherwise, we throw a usage exception:
    else {
        logcroak "Usage error"
    }

    # should we make sure that current package is not 'main'?
    if ( $class eq 'main' ) {
        logcroak "class 'main' cannot be the class name"
    }

    # creating the class virtually. Note, that it is different
    # then the way Class::Struct works. Class::Struct literally builds
    # the class contents in a string, and then eval()s them.
    # And we play with symtables. However, I'm not sure how secure this method is.

    no strict 'refs';
    # if the properties have already been created, it means the user
    # tried to create the class with the same name twice. He should be shot!
    if ( ${ "$class\::props" } ) {
        logcroak "are you trying to create the same class two times?"
    }

    # we should have some columns
    unless ( @{$props->{columns}} ) {
        logcroak "class '%s' should have columns!", $class
    }

    # one of the columns should be 'id'. I believe this is a limitation,
    # which should be eliminated in next release
    my $has_id = 0;
    for ( @{$props->{columns}} ) {
        $has_id = ($_ eq 'id') and last
    }
    unless ( $has_id ) {
        logcroak "'id' column is required! Read 'TODO' section of the manual for more details"
    }

    # certain method names are reserved. Making sure they won't get overridden
    my @reserved_methods = qw(load new save pobject_init DESTROY);
    for my $method ( @reserved_methods ) {
        for my $column ( @{$props->{columns}} ) {
            if ( $method eq $column ) {
                logcroak "method  '%s' is reserved", $method
            }
        }
    }

    # we should also check if the type map was specified for all the columns.
    # if not, we specify it for them:
    for my $colname ( @{$props->{columns}} ) {
        unless ( defined($props->{tmap}) && $props->{tmap}->{$colname} ) {
            if ( $colname eq 'id' ) {
                logtrc 1, "column '%s' defaulting to 'INTEGER'", $colname;
                $props->{tmap}->{$colname} = 'INTEGER';
                next
            }
            logtrc 1, "column '%s' defaulting to 'VARCHAR(250)'", $colname;
            $props->{tmap}->{$colname}   = 'VARCHAR(250)'
        }
    }

    # if no driver was specified, default driver to be used is 'file'
    unless ( $props->{driver} ) {
        logtrc 1, "'driver' is missing. Defaulting to 'file'";
        $props->{driver} = 'file'
    }

    # it's important that we cache all the properties passed so the pobject()
    # as a static data. This lets multiple instances of the pobject to access
    # this data whenever needed
    ${ "$class\::props" }   = $props;

    require Class::PObject::Template;

    *{ "$class\::new" }         = \&Class::PObject::Template::new;
    *{ "$class\::columns" }     = \&Class::PObject::Template::columns;
    *{ "$class\::load" }        = \&Class::PObject::Template::load;
    *{ "$class\::save" }        = \&Class::PObject::Template::save;
    *{ "$class\::remove" }      = \&Class::PObject::Template::remove;
    *{ "$class\::remove_all" }  = \&Class::PObject::Template::remove_all;
    *{ "$class\::count" }       = \&Class::PObject::Template::count;
    *{ "$class\::errstr" }      = \&Class::PObject::Template::errstr;
    *{ "$class\::dump" }        = \&Class::PObject::Template::dump;
    *{ "$class\::__props" }     = \&Class::PObject::Template::__props;
    *{ "$class\::__driver" }    = \&Class::PObject::Template::__driver;

    # installing accessor methods, only if they haven't already been defined
    for my $colname ( @{$props->{columns}} ) {
        if ( $class->UNIVERSAL::can($colname) ) {
            logtrc 1, "method '%s' already exists in the caller's package", $colname;
            next
        }
        *{ "$class\::$colname" } = sub {
            if ( @_ == 2 ) {
                $_[0]->{columns}->{$colname}    = $_[1];
                $_[0]->{_modified}->{$colname}  = 1
            }
            return $_[0]->{columns}->{$colname}
        }
    }
}

logtrc 1, "%s loaded successfully", __PACKAGE__;

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Class::PObject - Framework for programming persistent objects

=head1 SYNOPSIS

After loading the Class::PObject with F<use>, we can declare a pobject
like so:

    pobject Person => {
        columns     => ['id', 'name', 'email'],
        datasource  => './data'
    };

We can also declare the pobject in its own F<.pm> file:

    package Person;
    use Class::PObject;
    pobject {
        columns     => ['id', 'name', 'email''
        datasource  => './data'
    };

We can now create an instance of above Person, and fill it in with data, and
store it into disk:

    $person = new Person();
    $person->name('Sherzod');
    $person->email('sherzodr@cpan.org');
    $new_id = $person->save()

We can access the saved Person later, make necessary changes and save back:

    $person = Person->load($new_id);
    $person->name('Sherzod Ruzmetov (The Geek)');
    $person->save()

We can load multiple objects as well:

    @people = Person->load();
    for ( $i = 0; $i < @people; $i++ ) {
        $person = $people[$i];
        printf("[%02d] %s <%s>\n", $person->id, $person->name, $person->email)
    }

or we can load all the objects based on some criteria and sort the list by
column name in descending order, and limit the results to only the first 3 objects:

    @people = Person->load(
                    {name => "Sherzod"},
                    {sort => "name", direction => "desc", limit=>3});

We can also seek into a specific point of the result set:

    @people = Person->load(undef, {offset=>10, limit=>10});


=head1 WARNING

This is 'alpha' release. I mainly want to hear some ideas, criticism and suggestions from people.
Look at TODO section for more details.

=head1 DESCRIPTION

Class::PObject is a class framework for programming persistent objects. Such objects can store themselves
into disk, and recreate themselves from the disk.

If it is easier for you, just think of a persistent object as a single record of a relational database:

  +-----+----------------+--------+----------+
  | id  | title          | artist | album_id |
  +-----+----------------+--------+----------+
  | 217 | Yagonam O'zing | Sevara |        1 |
  +-----+----------------+--------+----------+

The above record of a song can be represented as a persistent object. Using Class::PObject,
you can define a class to represent this object like so:

    pobject Song => {
        columns => ['id', 'title', 'artist', 'album_id']
    };


Now you can create an instance of a Song with the following syntax:

    $song = new Song(title=>"Yagonam O'zing", artist=>"Sevara", album_id=>1);

All the disk access is performed through its drivers, thus allowing your objects truly transparent database
access. Currently supported drivers are L<mysql|Class::PObject::Driver::mysql>, L<file|Class::PObject::Driver::file> and L<csv|Class::PObject::Driver::csv>. More drivers can be added, and I believe will be.

=head1 PROGRAMMING STYLE

The style of Class::PObject is very similar to that of L<Class::Struct>. Instead of exporting 'struct()', however,  Class::PObject exports 'pobject()' function. Another visual difference is the way you declare the class. In Class::PObject, each property of the class is represented as a I<column>.

=head2 DEFINING OBJECTS

Object can be created in several ways. You can create the object in its own F<.pm> file with the following syntax:

    package Article;
    use Class::PObject;
    pobject {
        columns => ['id', 'title', 'date', 'author', 'source', 'text']
    };

Or you can also create an in-line object - from within your programs with more explicit declaration:

    pobject Article => {
        columns => ['id', 'title', 'date', 'author', 'source', 'text']
    };

Effect of the above two examples is identical - a class representing an Article.
By default, Class::PObject will fall back to L<file|Class::PObject::Driver::file> driver if you
do not specify any drivers. So the above Article object could also be redefined more explicitly like:

    pobject Article => {
        columns => \@columns,
        driver => 'file'
    };

The above examples are creating temporary objects. These are the ones stored in your system's temporary location.
If you want more I<permanent> objects, you should also declare its datasource:

    pobject Article => {
        columns => \@columns,
        datasource => './data'
    };

Now, the above article object will store its objects into F<data/article/> folder.
Since data storage is so dependant on the drivers, you should consult respective driver manuals for the details
of data storage-related topics.

Class declarations are tightly dependant to the type of driver being used, so we'll leave the rest of the declaration to specific drivers. In this document, we'll concentrate more on the user interface of the Class::PObject - something not dependant on the driver.

=head2 CREATING NEW OBJECTS

After you define a class using C<pobject()>, as shown above, now you can create instances of those objects.
Objects are created with new() - constructor method. To create an instance of the above Article object, we do:

    $article = new Article()

The above syntax will create an empty Article object. We can now fill I<columns> of this object one by one:

  $article->title("Persistent Objects with Class::PObject");
  $article->date("Sunday, June 08, 2003"),
  $article->author("Sherzod B. Ruzmetov");
  $article->source("lost+found (http://author.handalak.com)");
  $article->text("CONTENTS OF THE ARTICLE GOES HERE");

Another way of filling in objects, is by passing column values to the constructor - new():

    $article = new Article(title  =>  "Persistent Objects with Class::PObject",
                           date   =>  "Sunday, June 08, 2003",
                           author =>  "Sherzod Ruzmetov",
                           source =>  "lost+found (http://author.handalak.com" );

    $article->text("CONTENTS OF THE ARTICLE GO HERE");

Notice, above example is initializing all the properties of the object except for I<text> in the constructor,
and initializing I<text> separately. You can use any combination to fill in your objects.

=head2 STORING OBJECTS

Usually, when you create the objects and fill them with data, they are in-memory data structures, and not
attached to disk. This means as soon as your program terminates, or your object instance exits its scope
the data will be lost. It's when you call C<save()> method on the object when they are stored in disk.
To store the above Article, we could just say:

    $article->save();

C<save()> method returns newly created object I<id> on success, undef on failure. So you may want to check its
return value to see if it succeeded:

    $new_id = $article->save() or die $article->errstr;

B<Note:> we'll talk more about handling exceptions in later sections.

=head2 LOADING OBJECTS

No point of storing stuff if you can't retrieve them when you need them. PObjects support load() method which allows you to re-initialize your objects from the disk. You can retrieve objects in many ways. The easiest, and the most efficient way of loading an object from the disk is by its id:

    $article = Article->load(1251);

the above code is retrieving an article with id 1251. You can now either display the article on your web page:

    printf("<h1>%s</h1>",  $article->title);
    printf("<div>By %s</div>", $article->author);
    printf("<div>Posted on %s</div>", $article->date);
    printf("<p>%s</p>", $article->text);

or you can make some changes, say, change its title and save it back:

    $article->title("Persistent Objects in Perl made easy with Class::PObject");
    $article->save();

Other ways of loading objects can be by passing column values, in which case the object will retrieve all the objects from the database matching your search criteria:

    @articles = Article->load({author=>"Sherzod Ruzmetov"});

The above code will retrieve all the articles from the database written by "Sherzod Ruzmetov". You can specify more criteria to narrow your search down:

    @articles = Article->load({author=>"Sherzod Ruzmetov", source=>"lost+found"});

The above will retrieve all the articles written by "Sherzod Ruzmetov" and with source "lost+found". We can of course, pass no arguments to load(), in which  case all the objects of the same type will be returned.

Elements of returned @array are instances of Article objects. We can generate the list of all the articles with the following syntax:

    @articles = Article->load();
    for my $article ( @articles ) {
        printf("[%02d] - %s - %s - %s\n",
                $article->id, $article->title, $article->author, $article->date)
    }

load() also supports second set of arguments used to do post-result filtering. Using these sets you can sort the results by any column, retrieve first I<n> number of results, or do incremental retrievals. For example, to retrieve first 10 articles with the highest rating (assuming our Article object supports I<rating> column):

    @favorites = Article->load(undef, {sort=>'rating', direction=>'desc', limit=>10});

The above code is applying descending ordering on rating column, and limiting the search for first 10 objects. We could also do incremental retrievals. This method is best suited for web applications, where you can present "previous/next" navigation links and limit each listing to some I<n> objects:

    @articles = Article->load(undef, {offset=>10, limit=>10});

Above code retrieves records 10 through 20. The result set is not required to have a promising order.
If you need a certain order, you have to specify I<sort> argument with the name of the column you want to sort by.

    @articles = Article->load(undef, {sort=>'title', offset=>10, limit=>10});

By default I<sort> applies an ascending sort. You can override this behavior by defining I<direction> attribute:

    @articles = Article->load(undef, {sort=>'title', direction=>'desc'});

You can of course define both I<terms> and I<arguments> to load():

    @articles = Article->load({source=>'lost+found'}, {offset=>10, limit=>10, sort=>'title'});

If you C<load()> objects in array context as we've been doing above. In this case it returns
array of objects regardless of the number of objects retrieved.

If you call C<load()> in scalar context, regardless of the number of matching objects in the disk,
you will always retrieve the first object in the data set. For added efficiency, Class::PObject
will add I<limit=E<gt>1> argument even if it's missing.

=head2 COUNTING OBJECTS

Counting objects is very frequent task in many programs. You want to be able to display
how many Articles are in a web site, or how many of those articles have 5 out of 5 rating.

You can of course do it with a syntax similar to:

    @all_articles = Article->load();
    $count = scalar( @all_articles );

But some database drivers may provide a more optimized way of retrieving this information
using its meta-data. That's where C<count()> method comes in:

    $count = Article->count();

C<count()> also can accept \%terms, just like above C<load()> does as the first argument.
Using \%terms you can define conditional way of counting objects:

    $favorites_count = Article->count({rating=>'5'});

The above will retrieve a count of all the Articles with rating of '5'.

=head2 REMOVING OBJECTS

PObjects support C<remove()> and C<remove_all()> methods. C<remove()> is an object method.
It is used only to remove one object at a time. C<remove_all()> is a class method, which removes
all the objects of the same type, thus a little more scarier.

To remove an article with I<id> I<1201>, we first need to create the object of that article by loading it:

    # we first need to load the article:
    my $article = Article->load(1201);
    $article->remove();

remove() will return any true value indicating success, undef on failure.

    $article->remove() or die $article->errstr;

C<remove_all()> is invoked like so:

    Article->remove_all();

Notice, it's a static class method.

C<remove_all()> can also be used for removing objects selectively without having to load them
first. To do this, you can pass \%terms as the first argument to C<remove_all()>. These \%terms
are the same as the ones we used for C<load()>:

    Article->remove_all({rating=>1});

=head2 DEFINING METHODS OTHER THAN ACCESSORS

In some cases you want to be able to extend the class with custom methods.

For example, assume you have a User object, which needs to be authenticated
before they can access certain parts of the web site. It may be a good idea to
add "authenticate()" method into your User class, which either returns the User
object if he/she is logged in properly, or returns undef, meaning the user isn't
logged in yet.

To do this we can simply define additional method, C<authenticate()>. Consider
the following example:

    package User;

    pobject {
        columns     => ['id', 'login', 'psswd', 'email'],
        datasource  => 'data/users'
    };

    sub authenticate {
        my $class = shift;
        my ($cgi, $session) = @_;

        # if the user is already logged in, return the object:
        if ( $session->param('_logged_in') ) {
            return $class->load({id=>$session->param('_logged_in')})
        }

        # if we come this far, we'll try to initialize the object with CGI parameters:
        my $login     = $cgi->param('login')    or return 0;
        my $password  = $cgi->param('password') or return 0;

        # if we come this far, both 'login' and 'password' fields were submitted in the form:
        my $user = $class->load({login=>$login, psswd=>$password});

        # if the user could be loaded, we set the session parameter to his/her id
        if ( defined $user ) {
            $session->param('_logged_in', $user->id)
        }
        return $user
    }

Now, we can check if the user is logged into our web site with the following code:

    use User;
    my $user = User->authenticate($cgi, $session);
    unless ( defined $user ) {
        die "You need to login to the web site before you can access this page!"
    }

    printf "<h2>Hello %s</h2>", $user->login;

Notice, we're passing L<CGI|CGI> and L<CGI::Session|CGI::Session> objects to C<authenticate()>.
You can do it differently depending on the tools you're using.

=head2 ERROR HANDLING

I<PObjects> try never to die(), and lets the programer to decide what to do on failure,
(unless of course, you insult it with wrong syntax).

Methods that may fail are the ones to do with disk access, namely, C<save()>, C<load()>, C<remove()> and C<remove_all()>. So it's advised you check these methods' return values before you assume any success. If an error occurs, the above methods return undef. More verbose error message will be accessible through errstr() method. In addition, C<save()> method should always return the object id on success:

    my $new_id = $article->save();
    unless ( defined $new_id ) {
        die "couldn't save the article: " . $article->errstr
    }

    Article->remove_all() or die "couldn't remove objects:" . Article->errstr;

=head1 MISCELLANEOUS METHODS

In addition to the above described methods, I<PObjects> also support the following
few useful ones:

=over 4

=item *

C<columns()> - returns hash-reference to all the columns of the object. Keys of the hash hold column names,
and their values hold respective column values:

    my $columns = $article->columns();
    while ( my ($k, $v) = each %$columns ) {
        printf "%s => %s\n", $k, $v
    }

=item *

C<dump()> - dumps the object as a chunk of visually formatted data structure using standard L<Data::Dumper|Data::Dumper>. This method is mainly useful for debugging.

=item *

C<errstr()> - class method. Returns the error message from last I/O operations, if any.
This error message is also available through C<$CLASS::errstr> global variable:

    $article->save() or die $article->errstr;
    # or
    $article->save() or  die $Article::errstr;

=item *

C<__props()> - returns I<class properties>. Class properties are usually whatever was passed to C<pobject()> as a hashref. This information is usually useful for driver authors only.

=item *

C<__driver()> - returns either already available driver object, or creates a new object and returns it.
Although not recommended, you can use this driver object to access driver's low-level functionality,
as long as you know what you are doing. For available driver methods consult with specific driver
manual, or contact the vendor.

=back

=head1 TODO

Following are the lists of features and/or fixes that need to be applied before considering
the library ready for production environment. The list is not exhaustive. Feel free to add your
suggestions.

=head2 MORE FLEXIBLE LOAD()

load() will not be all we need until it supports at least simple I<joins>. Something similar to the
following may do:

    @articles = Article->load(join => ['ObjectName', \%terms, \%args]);

I believe it's something to be supported by object drivers, that's where it can be performed more efficiently.

=head2 GLOBAL DESCTRUCTOR

PObjects try to cache the driver object for more extended periods than pobject's scope permits them
to. So a I<global desctuctor> should be applied to prevent unfavorable behaviors, especially under persistent environments, such as mod_perl or GUI.

Global variables that I<may> need to be cleaned up are:

=over 4

=item B<$Class::PObject::Driver::$drivername::__O>

Where C<$drivername> is the name of the driver used. If more than one driver is used in your project,
more of these variables may exist. This variable holds particular driver object.

=item B<$PObjectName::props>

Holds the properties for this particular PObject named C<$PObjectName>. For example, if you created
a pobject called I<Article>, then it's properties are stored in global variable C<$Aritlce::props>.

=back

For example, if our objects were using just a L<mysql|Class::PObject::Driver::mysql> driver, in our main
application we could've done something like:

    END {
        $Class::PObject::Driver::mysql::__O = undef;
    }

=head1 DRIVER SPECIFICATIONS

L<Class::PObject::Driver>, L<Class::PObject::Driver::DBI>

=head1 SEE ALSO

L<Class::PObject>,
L<Class::PObject::Driver>,
L<Class::PObject::Driver::DBI>,
L<Class::PObject::Driver::csv>,
L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzod@cpan.orgE<gt>, http://author.handalak.com/

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
