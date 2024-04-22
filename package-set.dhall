let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.6.21-20220215/package-set.dhall sha256:c4bd3b9ffaf6b48d21841545306d9f69b57e79ce3b1ac5e1f63b068ca4f89957
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "base"
      , repo = "https://github.com/dfinity/motoko-base"
      , version = "moc-0.11.1"
      , dependencies = [] : List Text
      },
      { name = "StableTrieMap"
      , repo = "https://github.com/NatLabs/StableTrieMap"
      , version = "main"
      , dependencies = [] : List Text
      },
      { name = "StableBuffer"
      , repo = "https://github.com/canscale/StableBuffer"
      , version = "v0.2.0"
      , dependencies = [] : List Text
      },
      { name = "itertools"
      , repo = "https://github.com/NatLabs/Itertools"
      , version = "v0.1.0"
      , dependencies = [] : List Text
      },
      { name = "sha2"
      , version = "0.5.0"
      , repo = "https://github.com/research-ag/sha2"
      , dependencies = [] : List Text
      },
      { name = "vector"
      , version = "main"
      , repo = "https://github.com/research-ag/vector"
      , dependencies = [] : List Text
      },
      { name = "motoko_numbers"
      , version = "v1.1.0"
      , repo = "https://github.com/edjCase/motoko_numbers"
      , dependencies = [] : List Text
      },
      { name = "rep-indy-hash"
      , version = "v0.1.1"
      , repo = "https://github.com/skilesare/RepIndyHash.mo"
      , dependencies = [] : List Text
      },
      { name = "cert"
      , version = "v0.1.3"
      , repo = "https://github.com/nomeata/ic-certification"
      , dependencies = [] : List Text}
    ]
let
  {- This is where you can override existing packages in the package-set

     For example, if you wanted to use version `v2.0.0` of the foo library:
     let overrides = [
         { name = "foo"
         , version = "v2.0.0"
         , repo = "https://github.com/bar/foo"
         , dependencies = [] : List Text
         }
     ]
  -}
  overrides =
    [] : List Package

in  upstream # additions # overrides
