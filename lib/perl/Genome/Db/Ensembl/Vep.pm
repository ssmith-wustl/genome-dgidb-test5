package Genome::Db::Ensembl::Vep;

use strict;
use warnings;
use Genome;

my $VEP_SCRIPT_PATH = "Vep.d/vep";
my $ENSEMBL_API_PATH = $ENV{GENOME_DB_ENSEMBL_API_PATH};

class Genome::Db::Ensembl::Vep {
    is => 'Command',
    doc => 'Run VEP',
    has => [
        version => {
            is => 'String',
            doc => 'version of the Variant Effects Predictor to use',
            valid_values => [qw(2_2)],
            is_optional => 1,
            default_value => "2_2",
        },
        input_file => {
            is => 'String',
            doc => 'File of variants to be annotated',
        },
        format => {
            is => 'String',
            doc => 'The format of the input file, or guess to try to work out format',
            valid_values => [qw(ensembl pileup vcf hgvs id guess)],
        },
        output_file => {
            is => 'String',
            doc => 'File of annotated variants.  Write to STDOUT by specifying -o STDOUT',
        },
        species => {
            is => 'String',
            doc => 'Species to use',
            is_optional => 1,
            default_value => 'human',
        },
        terms => {
            is => 'String',
            doc => 'Type of consequence terms to output',
            is_optional => 1,
            default_value => 'ensembl',
            valid_values => [qw(ensembl SO NCBI)],
        },
        sift => {
            is => 'String',
            doc => 'Add SIFT [p]rediction, [s]core or [b]oth',
            is_optional => 1,
            valid_values => [qw(p s b)],
        },
        polyphen => {
            is => 'String',
            doc => 'Add PolyPhen [p]rediction, [s]core or [b]oth',
            is_optional => 1,
            valid_values => [qw(p s b)],
        },
        condel => {
            is => 'String',
            doc => 'Add Condel SIFT/PolyPhen consensus [p]rediction, [s]core or [b]oth',
            is_optional => 1,
            valid_values => [qw(p s b)],
        },
        regulatory => {
            is => 'boolean',
            doc => 'Look for overlap with regulatory regions.',
            default_value => 0,
            is_optional => 1,
        },
        gene => {
            is => 'boolean',
            doc => 'Force output fo Ensembl gene identifier.',
            default_value => 0,
            is_optional => 1,
        },
        most_severe => {
            is => 'boolean',
            doc => 'Output only the most severe consequence per variation.  Transcript-specific columns will be left blank.',
            default_value => 0,
            is_optional => 1,
        },
    ],
};

sub help_brief {
    'Tool to run Ensembl VEP (Variant Effect Predictor)';
}

sub help_detail {
    return <<EOS
    Tool to run Ensembl VEP (Variant Effect Predictor).  For VEP documentation see:
    http://ensembl.org/info/docs/variation/vep/index.html
EOS
}

sub execute {
    my $self = shift;

    my $script_path = $VEP_SCRIPT_PATH.$self->{version}.".pl";
    my $string_args = join( ' ',
        map {
            my $value = $self->$_;
            defined($value) ? ("--".($_)." ".$value) : ()
        } qw(input_file format output_file species terms sift polyphen condel)
    );
    my $bool_args = join (' ',
        map {
            my $value = $self->$_;
            $value ? ("--".($_)) : ()
        } qw(regulatory gene most_severe)
    );

    my $host_param = defined $ENV{GENOME_DB_ENSEMBL_HOST} ? "--host ".$ENV{GENOME_DB_ENSEMBL_HOST} : ();
    my $user_param = defined $ENV{GENOME_DB_ENSEMBL_USER} ? "--user ".$ENV{GENOME_DB_ENSEMBL_USER} : ();
    my $password_param = defined $ENV{GENOME_DB_ENSEMBL_PASS} ? "--password ".$ENV{GENOME_DB_ENSEMBL_PASS} : ();
    my $port_param = defined $ENV{GENOME_DB_ENSEMBL_PORT} ? "--port ".$ENV{GENOME_DB_ENSEMBL_PORT} : ();

    my $cmd = "PERL5LIB=$ENSEMBL_API_PATH/ensembl-variation/modules:$ENSEMBL_API_PATH/ensembl/modules:$ENSEMBL_API_PATH/ensembl-functgenomics/modules:\$PERL5LIB perl $script_path $string_args $bool_args $host_param $user_param $password_param $port_param";
    Genome::Sys->shellcmd(
        cmd=>$cmd,
        input_files => [$self->{input_file}],
        output_files => [$self->{output_file}],
        skip_if_output_is_present => 0,
    );
    return 1;
}

1;

