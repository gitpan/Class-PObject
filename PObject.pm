package Class::PObject;

# $Id: PObject.pm,v 1.39.2.8 2003/09/06 10:14:55 sherzodr Exp $

use strict;
#use diagnostics;
use Log::Agent;
use vars ('$VERSION', '$revision');

$VERSION    = '2.06_02';
($revision) = '$Revision: 1.39.2.8 $' =~ m/Revision:\s*(\S+)/;

# configuring Log::Agent
logconfig(-level=>$ENV{POBJECT_DEBUG} || 0);

sub import {
    my $class       = shift;
    my $caller_pkg  = (caller)[0];

    unless ( @_ ) {
        no strict 'refs';
        *{ "$caller_pkg\::pobject" } = \&{ "$class\::pobject" };
        return 1
    }
    require Exporter;
    return $class->Exporter::import( @_ )
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
        logcroak "'main' cannot be the class name"
    }

    # creating the class virtually. Note, that it is different
    # then the way Class::Struct works. Class::Struct literally builds
    # the class contents in a string, and then eval()s them.
    # And we play with symtables. However, I'm not sure how secure this method is.

    no strict 'refs';
    # if the properties have already been created, it means the user
    # is declaring the class with the same name twice. He should be shot!
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
        logcroak "one of the columns must be 'id'"
    }

    # certain method names are reserved. Making sure they won't get overridden
    my @reserved_methods = qw(new load fetch save pobject_init set get DESTROY);
    for my $method ( @reserved_methods ) {
        for my $column ( @{$props->{columns}} ) {
            if ( $method eq $column ) {
                logcroak "method  '%s' is reserved", $method
            }
        }
    }

    for my $colname ( @{$props->{columns}} ) {
        unless ( defined($props->{tmap}) && $props->{tmap}->{$colname} ) {
            if ( $colname eq 'id' ) {
                $props->{tmap}->{$colname} = 'INTEGER', next
            }
            $props->{tmap}->{$colname}   = 'VARCHAR(255)'
        }
    }

    # if no driver was specified, default driver to be used is 'file'
    $props->{driver} ||= 'file';

    # it's important that we cache all the properties passed to the pobject()
    # as a static data. This lets multiple instances of the pobject to access
    # this data whenever needed
    ${ "$class\::props" }   = $props;

    require Class::PObject::Template;

    *{ "$class\::new" }         = \&Class::PObject::Template::new;
    *{ "$class\::columns" }     = \&Class::PObject::Template::columns;
    *{ "$class\::load" }        = \&Class::PObject::Template::load;
    *{ "$class\::fetch" }       = \&Class::PObject::Template::fetch;
    *{ "$class\::save" }        = \&Class::PObject::Template::save;
    *{ "$class\::remove" }      = \&Class::PObject::Template::remove;
    *{ "$class\::remove_all" }  = \&Class::PObject::Template::remove_all;
    *{ "$class\::count" }       = \&Class::PObject::Template::count;
    *{ "$class\::errstr" }      = \&Class::PObject::Template::errstr;
    *{ "$class\::dump" }        = \&Class::PObject::Template::dump;
    *{ "$class\::__props" }     = \&Class::PObject::Template::__props;
    *{ "$class\::__driver" }    = \&Class::PObject::Template::__driver;

    for my $colname ( @{ $props->{columns} } ) {
        if ( $class->UNIVERSAL::can($colname) ) {
            logcarp "method '%s' exists in the caller's package", $colname;
            next
        }
        *{ "$class\::$colname" } = sub {
            if ( @_ == 2 ) {
                my $set = \&Class::PObject::Template::set;
                return $set->( $_[0], $colname, $_[1] )
            }
            my $get = \&Class::PObject::Template::get;
            return $get->( $_[0], $colname )
        }
    }
}

logtrc 1, "%s loaded successfully", __PACKAGE__;

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Class::PObject - Simple framework for programming persistent objects

=head1 SYNOPSIS

After loading the Class::PObject with C<use>, we can declare a class like so

    pobject Person => {
        columns     => ['id', 'name', 'email'],
        datasource  => './data'
    };

We can also declare the class in its own F<.pm> file:

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
    for $person ( @people ) {
        printf("[%02d] %s <%s>\n", $person->id, $person->name, $person->email)
    }

or we can load all the objects based on some criteria and sort the list by
column name in descending order, and limit the results to only the first 3 objects:

    @people = Person->load(
                    {name => "Sherzod"},
                    {sort => "name", direction => "desc", limit=>3});

We can also seek into a specific point of the result set:

    @people = Person->load(undef, {offset=>10, limit=>10});

=head1 DESCRIPTION

Class::PObject is a simple class framework for programming persistent objects in Perl.
Such objects can store themselves into disk, and recreate themselves from disk.

=head1 PHILOSOPHY

This section has been moved into L<Class::PObject::Philosophy|Class::PObject::Philosophy>.

=head1 PROGRAMMING STYLE

The style of Class::PObject is very similar to that of L<Class::Struct|Class::Struct>.
Instead of exporting 'struct()', however,  Class::PObject exports C<pobject()> function.
Another visual difference is the way you declare the class. In Class::PObject, each property
of the class is represented as a I<column>.

Suppose, you have a database called "person" with the following records:

    # person
    +-----+----------------+------------------------+
    | id  | name           | email                  |
    +-----+----------------+------------------------+
    | 217 | Sherzod        | sherzodr[AT]cpan.org   |
    +-----+----------------+------------------------+

=head2 CLASS DECLARATIONS

Let's declare a class first to represent the above data as a Persistent Object (pobject for short).
To do this, we first load the Class::PObject with C<use>, and declare a class with C<pobject()>
function, like so:

    use Class::PObject;
    pobject Person => {
        columns => ["id", "name", "email"]
    };

Above construct is declaring a Class representing a Person object. Person object
has 3 attributes that are called I<columns> in the I<pobject()> declaration. These are I<id>,
I<name> and I<email>.

Above is called in-line declaration, because you are creating an inline object -
the one that doesn't need to be in its own class file. You could declare it almost anywhere
inside your Perl code.

In-line declarations are not very useful, because you cannot access them separately
from within another application without having to re-declare identical class several times
in each of your programs.

Another, more recommended way of declaring classes is in their own F<.pm> files. For example,
inside a F<Person.pm> file we may put:

    # lib/Person.pm
    package Person;
    use Class::PObject;
    pobject Person => {
        columns => ["id", "name", "email"]
    };

    __END__;

That can be the whole content of your Perl module.

Now, from any other application all we need to do is to load F<Person.pm>, and access all
the nifty things it has to offer:

    # inside our app.cgi, for example:
    use Person;
    ....

=head2 OBJECT STORAGE

From the above class declaration you may be wondering, how does it now how and where the object data
are stored? The fact is, it doesn't. That's why by default it stores your objects in your system's temporary
folder, wherever it may be, using default L<file|Class::PObject::Driver::file> driver. To control this
behavior you can define I<driver> and I<datasource> attributes in addition to the above I<columns> attribute:

    pobject Person => {
        columns     => ["id", "name", "email"],
        datasource  => './data'
    };

Now, it's still using the default L<file|Class::PObject::Driver::file> driver, but storing
the objects in your custom, F<./data> folder.

You could've also chosen to store your objects in a DBM file, or in mysql tables. That's where
you will need to define your I<driver> attribute.

To store them in L<BerkelyDB|BerkelyDB>, using L<DB_File|DB_File>

    pobject Person => {
        columns => ["id", "name", "email"],
        driver  => 'db_file',
        datasource => './data'
    };

To store them in Comma Separated text files using L<DBD::CSV|DBD::CSV>:

    pobject Person => {
        columns => ["id", "name", "email"],
        driver  => 'csv',
        datasource {
            Dir => './data'
        }
    };

Or, to store them in a mysql database using L<DBD::mysql|DBD::mysql>:

    pobject Person => {
        columns => ["id", "name", "email"],
        driver  => 'mysql',
        datasource => {
            DSN      => "dbi:mysql:people",
            User     => "sherzodr",
            Password => "secret"
        }
    };

So forth. For more options you should refer to respective object driver manual.

=head2 CREATING NEW PERSON

After having the above Person class declared, we can now create an instance of a
new Person with the following syntax:

    $person = new Person();

Now what we need is to fill in the C<$person>'s attributes, and save it into disk

    $person->name("Sherzod Ruzmetov");
    $person->email("sherzodr[AT]cpan.org");
    $person->save();

As soon as you call C<save()> method of the C<$person>, all the records will be saved into
the disk.

Notice, we didn't give any value for the I<id> column. Underlying object drivers
will automatically generate a new ID for your newly created object, and C<save()>
method will return this ID for you.

If you assign a value for I<id>, you better make sure that ID doesn't already exist. If it does,
the old object with that ID will be replaced with new object. So to be safe, just don't bother
defining any values for your ID columns, unless you have a really good reason.

Sometimes, if you have objects with few attributes, you may choose to both create your
Person and assign its values at the same time. You can do so by passing your column values
while creating the new person:

    $person = new Person(name=>"Sherzod Ruzmetov", email=>"sherzodr[AT]cpan.org");
    $person->save();

=head2 LOADING OBJECTS

PObjects support C<load()> class method, which allows you to retrieve your objects from the disk.
You can retrieve objects in many ways. The easiest, and the most efficient way of loading an object
from the disk is by its id:

    $person = Person->load(217);

Now, assuming the C<$person> could be retrieved successfully, we can access the attributes of the object like so:

    printf( "Hello %s!\n", $person->name )

Notice, we are using the same method names to access them as the ones we used to assign values with,
but this time with no arguments.

Above, instead of displaying the C<$person>'s name, we could also edit the name and save it back:

    $person->name("Sherzod The Geek");
    $person->save();

Sometimes you may choose to load multiple objects. Using the same C<load()> method,
we could assign all the result set into an array:

    @people = Person->load();

Each element of the C<@people> is a C<$person> object, and you could list all of them with the following
syntax:

    for my $person ( @people ) {
        printf("[%d] - %s <%s>\n", $person->id, $person->name, $person->email)
    }

Notice two different contexts C<load()> was used in. If you call C<load()> in scalar context,
regardless of the number of matching objects, you will always retrieve the first object in
the data set. For added efficiency, Class::PObject will add I<limit=E<gt>1> argument to C<load()>
even if it's missing, or exists with a different value.

If you called C<load()> in array context, you will always receive an array of objects, even
if result set consists of a single object.

Sometimes you just want to load objects matching a specific criteria, say, you want all the people
whose name are I<John>. You can achieve this by passing a hashref as the first argument to C<load()>:

    @johns = Person->load({name=>"John"});

Sets of key/value pairs passed to C<load()> as the first argument are called I<terms>.

You can also apply post-result filtering to your list, such as sorting by a specific column
in a specific order, and limit the list to I<n> number of objects and start the listing at
object I<n> of the result set. All these attributes can be passed as the second argument to
C<load()> in the form of a hashref and are called I<arguments> :

    @people = Person->load(undef, {sort=>'name', direction=>'desc', limit=>100});

Above C<@people> holds 100 C<$person> objects, all sorted by name in descending order.
We could use both terms and arguments at the same time and in any combination.

=head2 SUPPORTED ARGUMENTS OF load()

Arguments are the second set of key/value pairs passed to C<load()>. Some drivers
may look at this set as post-result-filters.

=over 4

=item C<sort>

Defines which column the list should be sorted in.

=item C<direction>

Denotes direction of the sort. Possible values are I<asc> meaning ascending sort, and
I<desc>, meaning descending sort. If C<sort> is defined, but no C<direction> is available,
I<asc> is implied.

=item C<limit>

Denotes the number of objects to be returned.

=item C<offset>

Denotes the offset of the result set to be returned. It can be combined with C<limit>
to retrieve a sub-set of the result set, in which case, result set starting at I<offset>
value and up to I<limit> number will be returned to the caller.

=back

=head2 INCREMENTAL LOAD

C<load()> may be all you need most of the time. If your objects are of larger size,
or if you need to operate on thousands of objects, your program may not have enough memory to
hold them all, because C<load()> tends to load all the matching objects to the memory.

If this is your concern, you are better off using C<fetch()> method instead. Syntax of C<fetch()>
is almost identical to C<load()>, with an exception that it doesn't accept object id
as the first argument. You can either use it without any arguments, or with any combination
of C<\%terms> and C<\%args> as needed, just like with C<load()>.

Another important difference is, it does not return any objects. It's return value is an
instance of L<Class::PObject::Iterator|Class::PObject::Iterator>, which helps
you to iterate through large data sets by loading them one at a time inside a C<while>-loop:

    $result = Person->fetch();
    while ( my $person = $result->next ) {
        ...
    }
    # or
    $result = Person->fetch({name=>"John"}, {limit=>100});
    while ( my $person = $result->next ) {
        ...
    }

For the list of methods available for C<$result> - iterator object refer to its
L<manual|Class::PObject::Iterator>.

=head2 COUNTING OBJECTS

Counting objects is very frequent task in many projects. You want to be able to display
how many people are in your database in total, or how many "John"s are there.

You can of course do it with a syntax similar to:

    @all = People->load();
    $count = scalar( @all );

This however, also means you will be loading all the objects to memory at the same time.

Even if we could've done it using an iterator class, as discussed earlier, some database
engines may provide a more optimized way of retrieving this information without having
to C<load()> any objects, by consulting available meta information. That's where
C<count()> class method comes in:

    $count = Person->count();

C<count()> can accept \%terms, just like above C<load()> does as the first argument.
Using \%terms you can define conditions:

    $njohns = Person->count({name=>"John"});

=head2 REMOVING OBJECTS

PObjects support C<remove()> and C<remove_all()> methods. C<remove()> is an object method.
It is used only to remove one object at a time. C<remove_all()> is a class method, which removes
all the objects of the same type, thus a little more scarier.

To remove a person with id 217, we first need to create an object of that Person, and only
then call C<remove()> method:

    $person = Person->load(217);
    $person->remove();

C<remove_all()> is a static class method, and is used for removing all the objects from the
database:

    Person->remove_all();

C<remove_all()> can also be used for removing objects selectively without having to load them
first. To do this, you can pass C<\%terms> as the first argument to C<remove_all()>. These C<\%terms>
are the same as the ones we used for C<load()>:

    Person->remove_all({rating=>1});

Notice, if we wanted  to, we still could've used a code similar to the following to remove
all the objects:

    $result = Person->fetch();
    while ( $person = $result->next ) {
        $person->remove
    }

However, this will require first loading the object to the memory one at a time, and then
removing one at a time. Most of the object drivers may offer a better, efficient way of removing
objects from the disk without having to C<load()> them. That's why you should rely on
C<remove_all()>.

=head2 COLUMN TYPES

Class::PObject lets you define types for your columns, also known as I<type-maps>. 
First off, what for?

Type-maps can be looked at as properties of each column. If you are familiar with RDBMS,
you are already familiar with them. They read as I<CHAR>, I<VARCHAR>, I<INTEGER>,
I<ENCRYPT>, I<MD5> etc.

Column types can be used for declaring a property for a column, defining a constraint
or input-output filtering of columns.

This same feature can also be used for defining object relationships, but let's talk
about it later, not to confuse you yet.

You can define a type for your columns by I<tmap> pobject attribute:

    pobject User => {
        columns => ['id', 'login', 'psswd', 'name'],
        tmap    => {
            id      => 'INTEGER',
            login   => 'CHAR(18)',
            psswd   => 'MD5',
            name    => 'VARCHAR(40)'
        }
    }

Above class declaration is defining a User class, with 4 columns, and defining the type
of each column, such as I<id> as an I<INTEGER> column, I<login> as a I<VARCHAR> column
and so forth.

You normally never have to declare any column types. If you don't, I<id> column will always
default to I<INTEGER>, and all other columns will always default to I<VARCHAR(255)>. So
you should declare your column types only if you don't agree with default types.

So in above example, I could've chosen to say:

    pobject User => {
        columns => ['id', 'login', 'psswd', 'name'],
        tmap    => {
            psswd   => 'MD5'
        }
    }

Notice, I am accepting default type values for all the columns except for I<psswd> column,
which should be encrypted using MD5 message digest algorithm before being stored into
disk.

Of course, if I didn't care about security as much, I could've chosen not to define
type-map for I<psswd> column either.


As of this release, available built-in column types are:

=over 4

=item INTEGER

Stands for INTEGER type. This type is handled through
L<Class::PObject::Type::INTEGER|Class::PObject::Type::INTEGER>. Currently
Class::PObject doesn't enforce any constraints, but this may (and most likely
will) change in the future releases, so be cautious.

=item CHAR(n)

Stands for CHARacter type with length I<n>. This type is handled through
L<Class::PObject::Type::CHAR|Class::PObject::Type::CHAR> class, which currently
doesn't enforce any constraints to the length of the column. This may change
in future releases, so be cautious.

=item VARCHAR(n)

Stands for VARIABLE CHARacter I<n> character long. Highest allowed value for I<n>
is usually 255 characters, but this is still not enforced, but this may change
in future releases, so be cautious. Handled through 
L<Class::PObject::Type::VARCHAR|Class::PObject::Type::VARCHAR> class.

=item TEXT

Stands for TEXT column, which normally denotes values longer than 255 characters.
As of this release TEXT columns are handled the same way as CHAR and VARCHAR columns.
This may change in future releases, so be cautious.

=item ENCRYPT

Stands for ENCRYPTed column types. It denotes values which need to be encrypted
using UNIX's C<crypt()> function before being stored into disk. Smart overloading allows
to do something like the following:


    $user = new User();
    $user->psswd('marley01');
    print $user->psswd; # prints 'ZG9nqo.9bPjGA'
    if ( $user->psswd eq "marley01") {
        print "Good!\n";
    } else {
        print "Bad!\n";

    }

The above example will print "Good". Notice, that even if C<psswd> method returns
encrypted password ('ZG9nqo.9bPjGA'), we could still compare it with an un-encrypted
string using Perl's built-in I<eq> operator to see if "marley01" would really equal
to 'ZG9nqo.9bPjGA' if encrypted.

=item MD5

Stands for MD5 message digest. It denotes values that need to be encrypted
using MD5 message digest algorithm before being stored into disk. Smart overloading
allows it to be used in similar way as I<ENCRYPT> column types

=back

Up to this section you noticed that objects' accessor methods have been returning
strings, right? Wrong! They have been returning objects of their appropriate types.
But you didn't notice them and kept treating them as strings because of smart
operator overloading feature of those objects.

This means, if at any time in your program you want to discover the type of a specific
column, you could simply use Perl's built-in I<ref()> function:

    print ref( $user->psswd), "\n"; # <-- prints ENCRYPT
    print ref( $user->name ), "\n"; # <-- print VARCHAR

=head2 DEFINING METHODS OTHER THAN ACCESSORS

In some cases accessor methods are not all the methods your class may ever need. It may
need some other behaviors. In cases like these, you can extend your class with custom methods.

For example, assume you have a "User" object, which needs to be authenticated
before they can access certain parts of the web site. It may be a good idea to
add C<authenticate()> method into your "User" class, which either returns a User
object if he/she is logged in properly, or returns undef, meaning the user isn't
logged in yet.

To do this we can simply define additional method, C<authenticate()> inside our F<.pm> file.
Consider the following example:

    package User;

    pobject {
        columns     => ['id', 'login', 'psswd', 'email'],
        datasource  => './data'
    };

    sub authenticate {
        my $class = shift;
        my ($cgi, $session) = @_;

        # if the user is already logged in, return the object:
        if ( my $user_id = $session->param('_logged_in') ) {
            return $class->load( $user_id )
        }

        # if we come this far, the user is not logged in yet, but still
        # might've submitted our login form:
        my $login     = $cgi->param('login')    or return 0;
        my $password  = $cgi->param('password') or return 0;

        # if we come this far, both 'login' and 'password' fields were submitted
        # in the form. So we try to load() the matching object:
        my $user = $class->load({login=>$login, psswd=>$password}) or return undef;

        # we store the user's Id in our session parameter, and return the user
        # object
        $session->param('_logged_in', $user->id);
        return $user
    }

    __END__;

Now, we can check if the user is logged into our web site with the following code:

    use User;
    my $user = User->authenticate($cgi, $session);
    unless ( defined $user ) {
        die "You need to login to the web site before you can access this page!"
    }
    printf "<h2>Hello %s</h2>", $user->login;

Notice, we're passing L<CGI|CGI> and L<CGI::Session|CGI::Session> objects to C<authenticate()>.
You can do it differently depending on the tools you're using.

=head2 HAS-A RELATIONSHIP THROUGH TYPE MAPPING

Some available tools prefer calling this feature as I<HAS-A> relationship, 
but Class::PObject prefers the term I<type-mapping>. For the sake of familiarity, 
let's look at it as I<HAS-A> relationship for now.

I<HAS-A> relationship says that a value in a specific column is actually an id
of another object. In RDBMS this particular column is known as I<foreighn key>, because
it holds the primary key of another (foreign) table.

You can define this relationship the same way as we did column types using
I<tmap> pobject attribute.

Suppose, we have two classes, Article and Author:

    pobject Author => {
        columns        => ['id', 'name', 'email']
    };

    pobject Article => {
        columns        => ['id', 'author', 'title', 'body'],
        tmap        => {
            author        => 'Author'
        }
    };

Notice, in the above Article class, we're defining its I<author> column
to be of I<Author> type. This type should match the name of the existing
class.

Now, we can create a new article with the following syntax:

    $author = Author->load({name=>'Sherzod Ruzmetov'});

    $article = new Article();
    $article->title("Class::PObject now supports HAS-A relationships");
    $article->body("***body of the article***");
    $article->author( $author );
    $article->save();

Notice, we passed C<$author> object to article's C<author()> method. 
Class::PObject retrieves the ID of the author and stores it into Article's
I<author> field.

When you choose to access I<author> field of the article, Class::PObject
will automatically load respective Author object.

    $article = Article->load(32);
    my $author = $article->author;
    printf "Author: %s\n", $author->name;


We could've also passed C<$author> as part of the \%terms while loading
articles:

    my $author = Author->load({name=>"Sherzod Ruzmetov"});
    @my_articles = Article->load({author=>$author});


As you noticed, defining HAS-A relationship is the same as defining
built-in column types. In fact, they are the same, with the exception
of smart overloading, which are available only in built-in type-maps, 
and not for objects in HAS-A relationship.

One can look at it as a restriction, but you don't have to :-).

=head2 ERROR HANDLING

I<PObjects> try never to C<die()>, and lets the programer to decide what to do on failure,
(unless of course, you insult it with wrong syntax).

Methods that may fail are the ones to do with disk access, namely, C<save()>, C<load()>, 
C<remove()> and C<remove_all()>. So it's advised you check these methods' return values before 
you assume any success. If an error occurs, the above methods return undef. More verbose error 
message will be accessible through errstr() method. In addition, C<save()> method should 
always return the object id on success:

    my $new_id = $person->save();
    unless ( defined $new_id ) {
        die "save() failed: " . $person->errstr
    }
    Person->remove_all() or die "remove_all() failed: " . Person->errstr;


=head1 MISCELLANEOUS METHODS

In addition to the above described methods, pobjects support the following
few useful ones:

=over 4

=item *

C<columns()> - returns hash-reference to all the columns of the object. Keys of the hash
hold column names, and their values hold respective column values:

    my $columns = $person->columns();
    while ( my ($k, $v) = each %$columns ) {
        printf "%s => %s\n", $k, $v
    }

=item *

C<dump()> - dumps the object as a chunk of visually formatted data structure using standard L<Data::Dumper|Data::Dumper>. This method is mainly useful for debugging.

=item *

C<errstr()> - class method. Returns the error message from last I/O operations, if any.
This error message is also available through C<$CLASS::errstr> global variable:

    $person = new Person() or die Person->errstr;
    # or
    $person->save() or $person->errstr;
    # or
    $person->save() or  die $Person::errstr;

=item *

C<__props()> - returns I<class properties>. Class properties are usually whatever was 
passed to C<pobject()> as a hashref. This information is usually useful for driver authors only.

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

=head2 MORE FLEXIBLE load()

C<load()> will not be all we need until it supports at least simple I<join>s.
I believe it's something to be supported by object drivers, that's where it can be performed more
efficiently.

=head2 GLOBAL DESCTRUCTOR

Pobjects try to cache the driver object for more extended periods than pobject's scope permits them
to. So a I<global desctuctor> should be applied to prevent unfavorable behaviors, especially 
under persistent environments, such as mod_perl or GUI.

Global variables that I<may> need to be cleaned up are:

=over 4

=item B<$Class::PObject::Driver::$drivername::__O>

Where C<$drivername> is the name of the driver used. If more than one driver is used in your project,
more of these variables may exist. This variable holds particular driver object.

=item B<$PObjectName::props>

Holds the properties for this particular PObject named C<$PObjectName>. For example, if you created
a pobject called I<Person>, then it's properties are stored in global variable C<$Person::props>.

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
L<Class::PObject::Driver::file>,
L<Class::PObject::Driver::DBI>,
L<Class::PObject::Driver::csv>,
L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzod@cpan.orgE<gt>, http://author.handalak.com/

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2003 Sherzod B. Ruzmetov. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

$Date: 2003/09/06 10:14:55 $

=cut
