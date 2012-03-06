package Genome::Db::Ensembl::Vep;

use strict;
use warnings;
use Genome;
use Cwd;

my ($VEP_DIR) = Cwd::abs_path(__FILE__) =~ /(.*)\//;
my $VEP_SCRIPT_PATH = $VEP_DIR . "/Vep.d/vep";
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
            valid_values => [qw(ensembl pileup vcf hgvs id guess bed)],
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
            is => 'Boolean',
            doc => 'Look for overlap with regulatory regions.',
            default_value => 0,
            is_optional => 1,
        },
        gene => {
            is => 'Boolean',
            doc => 'Force output fo Ensembl gene identifier.',
            default_value => 0,
            is_optional => 1,
        },
        most_severe => {
            is => 'Boolean',
            doc => 'Output only the most severe consequence per variation.  Transcript-specific columns will be left blank.',
            default_value => 0,
            is_optional => 1,
        },
        per_gene => {
            is => 'Boolean',
            doc => 'Output only the most severe consequence per gene.  The transcript selected is arbitrary if more than one has the same predicted consequence.',
            default_value => 0,
            is_optional => 1,
        },
        hgnc => {
            is => 'Boolean',
            doc => 'Adds the HGNC gene identifier (where available) to the output.',
            default_value => 0,
            is_optional => 1,
        },
        coding_only => {
            is => 'Boolean',
            doc => 'Only return consequences that fall in the coding regions of transcripts.',
            default_value => 0,
            is_optional => 1,
        },
        force => {
            is => 'Boolean',
            doc => 'By default, the script will fail with an error if the output file already exists.  You can force the overwrite of the existing file by using this flag.',
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
    Tool to run Ensembl VEP (Variant Effect Predictor).  For documentation on input format, see:
    http://useast.ensembl.org/info/docs/variation/vep/vep_formats.html

    It is recommended that the input file is in Ensembl's format:
    1    881907    881906    -/C    +
    5    140532    140532    T/C    +
    8    12600     12602     CGT/-  -

    The 5th column must always be a '+' because we always call variants on the forward strand.
    Any additional columns after the '+' strand column will not change the resulting annotation.
EOS
}

sub execute {
    my $self = shift;

    my $format = $self->format;
    my $input_file= $self->input_file;

    # sanity check for ensembl input, since some of us are unable to
    # keep our zero and one-based annotation files straight, and VEP
    # fails cryptically when given one-based indels

    if ($format eq "ensembl"){
        my $inFh = IO::File->new( $self->input_file ) || die "can't open file\n";
        while( my $line = $inFh->getline )
        {
            chomp($line);
            my @F = split("\t",$line);

            #skip headers and blank lines
            next if $line =~/^#/;
            next if $line =~/^Chr/;
            next if $line =~/^$/;


            my @vars = split("/",$F[3]);
            #check SNVs
            if(($vars[0] =~ /^\w$/) && ($vars[1] =~ /^\w$/)){
                unless ($F[1] == $F[2]){
                    die ("ERROR: ensembl format is 1-based. this line appears to be 1-based\n$line\n")
                }
            }
            #indel insertion
            elsif(($vars[0] =~ /^-$/) && ($vars[1] =~ /\w+/)){
                unless ($F[1] == $F[2]+1){
                    die ("ERROR: This line doesn't appear to be a valid ensembl format indel:\n$line\n")
                }
            }
            #indel deletion
            elsif(($vars[0] =~ /\w+/) && ($vars[0] =~ /^-$/)){
                unless ($F[1]+length($F[2])-1 == $F[1]){
                    die ("ERROR: This line doesn't appear to be a valid ensembl format indel\n$line\n")
                }
            }

        }
        close($inFh);
    }

    # If bed format is input, we do a conversion to ensembl format. This is necessary
    # because ensembl has some weird conventions. (Most notably, an insertion is
    # represented by changing the start base to the end base + 1 and a deletion is represented by
    # the numbers of the nucleotides of the bases being affected:
    #
    # 1  123  122  -/ACGT
    # 1  978  980  ACT/-

    if ($format eq "bed"){
        #create a tmp file for ensembl file
        my ($tfh,$tmpfile) = Genome::Sys->create_temp_file;
        unless($tfh) {
            $self->error_message("Unable to create temporary file $!");
            die;
        }
        open(OUTFILE,">$tmpfile") || die "can't open temp file for writing ($tmpfile)\n";

        #convert the bed file
        my $inFh = IO::File->new( $self->input_file ) || die "can't open file\n";
        while( my $line = $inFh->getline ){
            chomp($line);
            my @F = split("\t",$line);

            #skip headers and blank lines
            next if $line =~/^#/;
            next if $line =~/^Chr/;
            next if $line =~/^$/;

            #accept ref/var alleles as either slash or tab sep (A/C or A\tC)
            my @vars;
            my @suffix;
            if($F[3] =~ /\//){
                @vars = split(/\//,$F[3]);
                @suffix = @F[4..(@F-1)]
            } else {
                @vars = @F[3..4];
                @suffix = @F[5..(@F-1)]
            }
            $vars[0] =~ s/\*/-/g;
            $vars[0] =~ s/0/-/g;
            $vars[1] =~ s/\*/-/g;
            $vars[1] =~ s/0/-/g;

            #check SNVs
            if(($vars[0] =~ /^\w$/) && ($vars[1] =~ /^\w$/)){
                unless ($F[1] == $F[2]-1){
                    die ("ERROR: bed format is 0-based. This line is not:\n$line\n")
                }
                $F[1]++
            }
            #indel insertion
            elsif(($vars[0] =~ /^-|0$/) && ($vars[1] =~ /\w+/)){
                unless ($F[1] == $F[2]){
                    die ("ERROR: bed format is 0-based. this line is not:\n$line\n")
                }
                #increment the start position
                $F[1]++;
            }
            #indel deletion
            elsif(($vars[0] =~ /\w+/) && ($vars[1] =~ /^-|0$/)){
                unless ($F[1]+length($vars[0]) == $F[2]){
                    die ("ERROR: bed format is 0-based. this line is not:\n$line\n")
                }
                #increment the start position
                $F[1]++;
            } else {
                die ("This line is not a valid bed line:\n$line\n")
            }
            print OUTFILE join("\t",(@F[0..2],join("/",@vars),"+",@suffix)) . "\n";
        }


        $format = "ensembl";
        $input_file = $tmpfile;
        `cp $tmpfile /tmp/`;
    }


    my $script_path = $VEP_SCRIPT_PATH.$self->{version}.".pl";
    my $string_args = "";

    #UR magic to get the string and boolean property lists
    my $meta = $self->__meta__;
    my @all_bool_args = $meta->properties(
        class_name => __PACKAGE__,
        data_type => 'Boolean');
    my @all_string_args = $meta->properties(
        class_name => __PACKAGE__,
        data_type => 'String');

    my $count = 0;
    foreach my $arg (@all_string_args) {
        if ($arg->property_name eq 'version') {
            splice @all_string_args, $count, 1;
            last;
        }
        $count++;
    }

    $string_args = join( ' ',
        map {
            my $name = $_->property_name;
            my $value = $self->$name;
            defined($value) ? ("--".($name)." ".$value) : ()
        } @all_string_args
    );

    #have to replace these arg, because it may have changed (from bed -> ensembl)
    $string_args =~ s/--format (\w+)/--format $format/;
    $string_args =~ s/--input_file ([^\s]+)/--input_file $input_file/;

    my $bool_args = "";
    $bool_args = join (' ',
        map {
            my $name = $_->property_name;
            my $value = $self->$name;
            $value ? ("--".($name)) : ()
        } @all_bool_args
    );

    my $host_param = defined $ENV{GENOME_DB_ENSEMBL_HOST} ? "--host ".$ENV{GENOME_DB_ENSEMBL_HOST} : "";
    my $user_param = defined $ENV{GENOME_DB_ENSEMBL_USER} ? "--user ".$ENV{GENOME_DB_ENSEMBL_USER} : "";
    my $password_param = defined $ENV{GENOME_DB_ENSEMBL_PASS} ? "--password ".$ENV{GENOME_DB_ENSEMBL_PASS} : "";
    my $port_param = defined $ENV{GENOME_DB_ENSEMBL_PORT} ? "--port ".$ENV{GENOME_DB_ENSEMBL_PORT} : "";


    my $cmd = "PERL5LIB=$ENSEMBL_API_PATH/ensembl-variation/modules:$ENSEMBL_API_PATH/ensembl/modules:$ENSEMBL_API_PATH/ensembl-functgenomics/modules:\$PERL5LIB perl $script_path $string_args $bool_args $host_param $user_param $password_param $port_param";

    print STDERR $cmd . "\n";

    Genome::Sys->shellcmd(
        cmd=>$cmd,
        input_files => [$input_file],
        output_files => [$self->{output_file}],
        skip_if_output_is_present => 0,
    );
    return 1;
}

1;

