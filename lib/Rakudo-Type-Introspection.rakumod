use v6.*;
use nqp;  # for nqp::can, nqp::istype, nqp::objectid, nqp::decont

# Check if HOW comes from NQP
my constant %HOWisNQP = 
  'NQPClassHOW', True, 'NQPParametricRoleHOW', True
;

# Map a HOW to a namespace identifier
my constant %HOW2namespace = <
  NQPClassHOW                              class
  NQPParametricRoleHOW                     role
  Perl6::Metamodel::ClassHOW               class
  Perl6::Metamodel::CurriedRoleHOW         role[]
  Perl6::Metamodel::EnumHOW                enum
  Perl6::Metamodel::GrammarHOW             grammar
  Perl6::Metamodel::ModuleHOW              module
  Perl6::Metamodel::NativeHOW              native
  Perl6::Metamodel::NativeRefHOW           nativeref
  Perl6::Metamodel::PackageHOW             package
  Perl6::Metamodel::ParametricRoleGroupHOW role
  Perl6::Metamodel::SubsetHOW              subset
>;

sub basenameHOW(Mu $type) { $type.HOW.^name.split('HOW',2).head ~ 'HOW' }

#- exported subs ---------------------------------------------------------------

# Produce list of "is" classes of a type
proto sub parents(|) is export {*}
multi sub parents(Mu:D $value) { parents($value.WHAT) }
multi sub parents(Mu:U $type) {

    # Need special casing to handle Nil properly
    my @parents is default(Nil) = nqp::can($type.HOW,"mro")
      ?? $type.^mro.skip
      !! Empty;

    # Not Mu
    if @parents {
        my int $i = @parents.elems;
        while --$i {
            my $that := @parents[$i];
            for @parents[^$i] -> $this {

                # Already a parent class in list
                if nqp::istype($this,$that) {
                    @parents.splice($i,1);
                    last;
                }
            }
        }
        @parents.List
    }

    # Presumably Mu
    else {
        ()  # UNCOVERABLE
    }
}

# Produce list of "does" roles of a type
proto sub does(|) is export {*}
multi sub does(Mu:D $value) { does($value.WHAT) }
multi sub does(Mu:U $type) {

    # Ignore some weird internals
    CATCH { return () }

    # At least one role
    if nqp::can($type.HOW,"roles") && $type.^roles -> @does is copy {
        my int $i = @does.elems;
        while --$i {
            my $that := @does[$i];

            # Already a parent role in list
            for @does[^$i] -> $this {
                if nqp::istype($this,$that) {
                    @does.splice($i,1);
                    last;
                }
            }
        }

        $i = @does.elems;
        my @parents := parents($type);
        while --$i >= 0 {
            my $that := @does[$i];

            # A parent class already does the role
            for @parents -> $this {
                if nqp::istype($this,$that) {
                    @does.splice($i,1);
                    last;
                }
            }
        }
        @does.List
    }

    # No roles
    else {
        ()  # UNCOVERABLE
    }
}

# Produce whether a type is CORE, and from which version
proto sub core(|) is export {*}
multi sub core(Mu:D $value) { core($value.WHAT) }
multi sub core(Mu:U $type) {

    if try $type.^name -> str $name {
        my $target := nqp::decont($type);

        my str @parts = $name.split("::");
        if @parts.elems == 1 {
            for <v6c v6d v6e> -> $core {
                return $core
                  if nqp::eqaddr((try CORE::{$core}.WHO{$name}),$target);
            }
        }
        else {
            LEVEL:
            for <v6c v6d v6e> -> $core {
                my $WHO := CORE::{$core}.WHO;

                for @parts -> $part {
                    $WHO{$part}:exists
                      ?? ($WHO := $WHO{$part}.WHO)
                      !! (next LEVEL)
                }
                return $core;
            }
        }
    }

    ""
}

# Produce the namespace of a type
proto sub namespace(|) is export {*}
multi sub namespace(Mu:D $value) { namespace($value.WHAT)             }
multi sub namespace(Mu:U $type)  { %HOW2namespace{basenameHOW($type)} }


# True if given type originated from NQP
proto sub nqp(|) is export {*}
multi sub nqp(Mu:D $value) { nqp($value.WHAT)                       }
multi sub nqp(Mu:U $type)  { %HOWisNQP{basenameHOW($type)} // False }

# Cache of Rakudo types, so that each type has its own Rakudo::Type object
my %types;

#- Rakudo::Type ----------------------------------------------------------------
class Rakudo::Type {
    has Mu           $.type;
    has str          $.namespace;
    has str          $.name;
    has str          $.core;
    has Bool         $.nqp;
    has Rakudo::Type @.parents  is built(:bind);
    has Rakudo::Type @.does is built(:bind);

    multi method new(Rakudo::Type:U: Mu $object) {
        my $type := nqp::decont($object).WHAT;

        if nqp::isconcrete($type.HOW) {

            # Seen this type before
            if %types{nqp::objectid($type)} -> $cached {
                $cached
            }

            # Has a HOW that we support
            elsif namespace($type) -> $namespace is copy {

                # Handle curried roles
                if $namespace eq 'role[]' {
                    $type     := $type.^curried_role;
                    $namespace = 'role'
                }

                my str $name = $type.^name;
                my str $core = core($type);
                my     $nqp := nqp($type);

                my @parents  = parents($type).map:  { Rakudo::Type.new($_) }
                my @does = does($type).map: { Rakudo::Type.new($_) }

                %types{$name} := self.bless(
                  :$type, :$namespace, :$core, :$nqp, :$name, :@parents, :@does
                )
            }

            # An unsupported HOW, don't bother to try again
            else {
#say "unsupported: $type.^name()";
                %types{nqp::objectid($type)} := Nil
            }
        }
        else {
            Nil
        }
    }

    multi method Str(Rakudo::Type:D:) { $!name }

    multi method gist(Rakudo::Type:D:) {
        my str @parts =
          $!namespace,
          $!core && $!core ne 'v6c' ?? $!core ~ "::$!name" !! $!name
        ;
        @parts.append: @!parents.map:  { "is $_.name()"   }
        @parts.append: @!does.map: { "does $_.name()" }
        @parts.join(" ");
    }

    method core-name(Rakudo::Type:D:) {
        $!core ?? "CORE::$!core" ~ "::$!name" !! $!name
    }
}

#- problem cases ---------------------------------------------------------------

# Make sure the problem cases are already taken into account
BEGIN {

    # NQP classes that aren't properly introspectable
    my \NQPMu := ContainerDescriptor.^mro[1];  # UNCOVERABLE
    my \NQPMuRT :=  # UNCOVERABLE
      %types{nqp::objectid(NQPMu)} :=  # UNCOVERABLE
        Rakudo::Type.bless( 
          :type(NQPMu), :namespace<class>, :nqp, :name<NQPMu>
        );
    %types{nqp::objectid(ContainerDescriptor)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(ContainerDescriptor), :namespace<class>,
        :name<ContainerDescriptor>, :nqp, :parents(NQPMuRT,)
      );
    %types{nqp::objectid(NQPMatchRole)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Match.^roles[0]),  # UNCOVERABLE
        :namespace<role>, :nqp, :name<NQPMatchRole>
      );

    # Basic types
    my \MuRT = %types{nqp::objectid(Mu)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Mu), :namespace<class>, :name<Mu>, :core<v6c>
      );
    my \AnyRT = %types{nqp::objectid(Any)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Any), :namespace<class>, :name<Any>, :core<v6c>, :parents(MuRT,)
      );
    my \CoolRT = %types{nqp::objectid(Cool)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Cool), :namespace<class>, :name<Cool>, :core<v6c>, :parents(AnyRT,)
      );
    my \NilRT = %types{nqp::objectid(Nil)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Nil), :namespace<class>, :name<Nil>, :core<v6c>, :parents(CoolRT,)
      );
    %types{nqp::objectid(Exception)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Exception), :namespace<class>, :name<Exception>, :core<v6c>,
        :parents(AnyRT,)
      );
    %types{nqp::objectid(Failure)} :=  # UNCOVERABLE
      Rakudo::Type.bless(
        :type(Failure), :namespace<class>, :name<Failure>, :core<v6c>,
        :parents(NilRT,)
      );
}

#- Rakudo-Type-Introspection ---------------------------------------------------
class Rakudo-Type-Introspection {
    has %!types is built is Map;

    proto method new(|) {*}

    multi method new(Rakudo-Type-Introspection:U:
      CORE::v6c::PseudoStash:D $stash = CORE::,  # both 6c/e PseudoStash
      :$implementation-detail, :$nqp, :$package, :$rakuast
    ) {
        my %types = $stash.pairs.sort(*.key.fc).map: -> $pair {
            my $name := $pair.key;
            my $type := $pair.value;

            # Skipping?
            if nqp::isconcrete($type)                 # no values
              || $name eq 'EXPORTHOW'                 # is just for exporting
              || (!$implementation-detail             # no internals, unless
                   && try $type.^is-implementation-detail)
              || (!$rakuast && $name eq 'RakuAST') {  # UNCOVERABLE
                Empty
            }

            # Doing this type and its children
            else {
                my @rts;

                my sub process(Mu $type) {
                    # Only handle type values
                    if !nqp::isconcrete($type)
                      && ($implementation-detail
                           || !try $type.^is-implementation-detail)
                      && Rakudo::Type.new($type) -> $object {
                        @rts.push($object)
                          unless (!$nqp && $object.nqp)
                            || (!$package && $object.namespace eq 'package')
                    }

                    if namespace($type) andthen $_ ne 'enum'
                      && $type.WHO -> $WHO {
                        process($_) for $WHO.values;
                    }
                }
                process($type);

                @rts.map({ .core-name => $_ }).Slip
            }
        }

        # Make sure all dependent types are also findable
        for %types.values -> $type {
            for $type.parents -> $parents {
                my $name := $parents.core-name;
                %types{$name} //= $parents;
            }
            for $type.does -> $does {
                my $name := $does.core-name;
                %types{$name} //= $does;
            }
        }

        self.bless(:%types)
    }

    method AT-KEY(Rakudo-Type-Introspection:D: str $key) {
        my %types := %!types;
        %types.AT-KEY($key)
          // %types.AT-KEY("CORE::v6c::$key")
          // %types.AT-KEY("CORE::v6d::$key")
          // %types.AT-KEY("CORE::v6e::$key")
    }

    my sub normalize-key($key) { $key.subst(/^ 'CORE::v6' <[cde]> '::'/ ).fc }

    method iterator(Rakudo-Type-Introspection:D:) {
        self.pairs.iterator
    }

    method pairs(Rakudo-Type-Introspection:D:) {
        %!types.sort({ normalize-key(.key) })
    }
    method keys(Rakudo-Type-Introspection:D:) {
        %!types.keys.sort(&normalize-key)
    }
    method values(Rakudo-Type-Introspection:D:) {
        %!types.sort({ normalize-key(.key) }).map(*.value)
    }
    method kv(Rakudo-Type-Introspection:D:) {
        %!types.sort({ normalize-key(.key) }).map: { (.key, .value).Slip }
    }
}

# vim: expandtab shiftwidth=4
