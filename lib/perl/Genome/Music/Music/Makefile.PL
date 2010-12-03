use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Music',
    AUTHOR              => 'The Genome Center at Washington University <ndees@genome.wustl.edu>',
    VERSION_FROM        => 'lib/Music.pm',
    ABSTRACT_FROM       => 'lib/Music.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Music-*' },
);
