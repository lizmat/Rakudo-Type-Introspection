[![Actions Status](https://github.com/lizmat/Rakudo-Type-Introspection/actions/workflows/linux.yml/badge.svg)](https://github.com/lizmat/Rakudo-Type-Introspection/actions) [![Actions Status](https://github.com/lizmat/Rakudo-Type-Introspection/actions/workflows/macos.yml/badge.svg)](https://github.com/lizmat/Rakudo-Type-Introspection/actions) [![Actions Status](https://github.com/lizmat/Rakudo-Type-Introspection/actions/workflows/windows.yml/badge.svg)](https://github.com/lizmat/Rakudo-Type-Introspection/actions)

NAME
====

Rakudo-Type-Introspection - introspect Raku types

SYNOPSIS
========

```raku
use Rakudo-Type-Introspection;

my $type = Rakudo::Type.new(Rat);
say $type.isa;   # Cool
say $type.does;  # Rational

my $introspection = Rakudo::Type::Introspection.new(CORE::);
say $introspection<Int>.name;  # Int

say isa(IO::Path);   # Cool
say does(IO::Path);  # IO
say core(IO::Path);  # v6c
```

DESCRIPTION
===========

The `Rakudo-Type-Introspection` distribution provides the logic to introspect Raku types and `PseudoStash`es.

CLASSES
=======

Rakudo::Type
------------

```raku
my $type = Rakudo::Type.new(IntStr);
say $type.core;       # v6c
say $type.namespace;  # class
```

The `Rakudo::Type` object collects information about a type. It can instantiated by specifying a single positional argument to the `new` method.

### ATTRIBUTES

The `Rakudo::Type` class contains the following public attributes, which can also be specified as named arguments to the `new` methdod.

#### type

The actual type object that was used to create the `Rakudo::Type` object.

#### namespace

The type of namespace (scope) of the type. One of the following:

  * class

  * enum

  * grammar

  * module

  * native

  * nativeref

  * package

  * role

  * subset

#### name

The name of the type, as introspected with `.^name`.

#### core

The core level in which the type was defined, as a string. One of the following:

  * "v6c"

  * "v6d"

  * "v6e"

  * "" - not a core type

#### nqp

Boolean, indicating whether the type was created in NQP.

#### isa

A `List` of `Rakudo::Type` objects of unique parent classes.

#### does

A `List` of `Rakudo::Type` objects of unique roles (also excluding any roles that have already been consumed by any parent class).

### METHODS

#### gist

```raku
say Rakudo::Type.new(IntStr); # class IntStr is Allomorph is Int
```

The `gist` method provides a simple representation of the type, almost as if written in Raku.

Rakudo-Type-Introspection
-------------------------

```raku
my $introspection = Rakudo::Type::Introspection.new(CORE::);
say $introspection<IO::Path>.does;  # IO
```

The `Rakudo-Type-Introspection` class incorporates the logic to recursively collect the type information of a given `PseudoStash` (with the `CORE::` `PseudoStash` taken as the default).

It exposes the information as a `Map` keyed on the full name of all the types found in the given `PseudoStash`, with the value being the associated `Rakudo::Type` object.

### method new

The `new` method additionally takes the following named arguments:

#### :implementation-detail

Will include types that have been marked as `is implementation-detail` if specified with a trueish value. Default is to **not** include types that are implementation details.

#### :nqp

Will include types that originated from NQP code if specified with a trueish value. Default is to **not** include types from NQP.

#### :package

Will include `package` types if specified with a trueish value. Default is to **not** include `package`s.

#### :rakuast

Will include `RakuAST::...` classes if specified with a trueish value. Default is to **not** include `RakuAST::...` classes.

EXPORTED SUBROUTINES
====================

Some basic functionality is exported as subroutines.

isa
---

```raku
say isa(Int);  # Cool
dd Int.^mro;   # (Int, Cool, Any, Mu)
```

The `isa` subroutine takes a type object and returns a list of types of unique parent classes. This is different from what the `.^mro` method returns. Because `Cool` is an `Any`, and `Any` is a `Mu`, the specification of `is Cool` is enough in a `class Foo is Cool` statement.

does
----

```raku
say does(Int);  # Real
dd Int.^roles;  # (Real, Numeric)
```

The `does` subroutine takes a type object and returns a list of unique roles that are consumed by the class. This is different from what the `.^roles` method returns. Because the `Real` role consumed the `Numeric` role, the specification of `does Real` is enough in a `class Bar does Real` statement.

core
----

```raku
use v6.e.PREVIEW;
dd core(Int);            # "v6c"
dd core(Formatter);      # "v6e"
dd core(class Foo { });  # ""
```

The `core` subroutine takes a type object and returns a string indicating in which core level the type was defined, or it returns the empty string if the type could not be found in core.

namespace
---------

```raku
dd namespace(IO);   # "role"
dd namespace(Int);  # "class"
```

The `namespace` subroutine takes a type object and returns a string indicating the type of namespace (scope) of the type.

nqp
---

```raku
dd nqp(IO);                   # False
dd nqp(Metamodel::ClassHOW);  # True
```

The `nqp` subroutine takes a type object and returns a `Bool` indicating whether or not the type originated from NQP.

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://codeberg.org/lizmat/Rakudo-Type-Introspection . Comments and Pull Requests are welcome.

If you like this module, or what I'm doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2026 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

