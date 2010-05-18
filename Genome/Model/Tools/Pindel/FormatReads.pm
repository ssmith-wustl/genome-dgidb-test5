package Genome::Model::Tools::Pindel::FormatReads;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Pindel::FormatReads {
    is => ['Command'],
    has => [
        sw_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'File of smith waterman reads to be sorted, dumped from samtools view. ',
        },
        one_end_reads => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'File of single reads to be sorted, dumped from samtools view. Must be sorted such that their mate read is adjacent in the file (such as with gmt pindel sort-mate).',
        },
        output_file_sw => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The output file for smith waterman reads, formatted in the pindel input format',
        },
        output_file_one_end => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The output file for single end mapped reads, formatted in the pindel input format',
        },
        tag => {
            is => 'string',
            is_input => '1',
            doc => 'The tag to be associated with all of these reads. Useful for distinguishing samples. I.E. BRC1T, OV1M, etc',
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        _ms_cutoff => {
            is => 'Integer',
            default => 0,
            doc => '',
        },
    ],
};
        
sub help_brief {
    "Translates reads from samtools view format to pindel input format";
}

sub help_synopsis {
    return <<"EOS"
gmt pindel format-reads --sw-reads dumped_reads.sw --one-end-reads dumped_reads.oneend --output-file-sw formatted_sw.out --output-file-one-end formatted_one_end.out --tag BRC1
gmt pindel format-reads --sw dumped_reads.sw --one dumped_reads.oneend --output-file-sw formatted_sw.out --output-file-one formatted_one_end.out --tag BRC1
EOS
}

sub help_detail {                           
    return <<EOS 
Takes in reads dumped from a bam via samtools view and produces and output file formatted such that pindel can take it as input. Each read will be translated into three lines that pindel can read.
EOS
}

sub execute {
    my $self = shift;
    $DB::single = 1;

    # Skip if output files exist
    if (($self->skip_if_output_present)&&(-s $self->output_file_sw)&&(-s $self->output_file_one_end)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    my $sw_ifh = IO::File->new($self->sw_reads);
    unless($sw_ifh) {
        $self->error_message("Unable to open " . $self->sw_reads. " for reading. $!");
        die;
    }
    my $one_end_ifh = IO::File->new($self->one_end_reads);
    unless($one_end_ifh) {
        $self->error_message("Unable to open " . $self->one_end_reads. " for reading. $!");
        die;
    }

    my $sw_ofh = IO::File->new($self->output_file_sw, "w");
    unless($sw_ofh) {
        $self->error_message("Unable to open " . $self->output_file_sw . " for writing. $!");
        die;
    }
    my $one_end_ofh = IO::File->new($self->output_file_one_end, "w");
    unless($one_end_ofh) {
        $self->error_message("Unable to open " . $self->output_file_one_end . " for writing. $!");
        die;
    }

    #FIXME make one set or the other optional
    while (my $line = $sw_ifh->getline) {
        $self->parse_smith_waterman($line, $sw_ofh);
    }

    while (my $line = $one_end_ifh->getline) {
           my $line2 = $one_end_ifh->getline;
           $self->parse_one_end($line, $line2, $one_end_ofh);
    }

    $sw_ifh->close;
    $sw_ofh->close;
    $one_end_ifh->close;
    $one_end_ofh->close;

    return 1; 
}

sub parse_smith_waterman {
    my ($self, $line, $ofh) = @_; 
    my ($name, $flag, $chromosome, $position, $ms, $insert_size, $sequence) = split(/\s+/, $line);

    my ($mate_strand, $mate_position);
    if (($flag / 16) % 2 == 0) { #forwards (mate is reverse)
        $mate_strand = "-";
        $mate_position = $position + ($insert_size - length $sequence);
    } else { #reverse (mate is forwards)
        $mate_strand = "+";
        $sequence = $self->reverse_complement($sequence);
        $mate_position = $position - ($insert_size - 2 * length $sequence);
    }

    return unless $self->is_valid_read($chromosome, $mate_position);

    $ofh->print("\@$name\n");
    $ofh->print("$sequence\n");
    $ofh->print( join("\t",($mate_strand, $chromosome, $mate_position, $ms, $self->tag) ) . "\n");
}

sub parse_one_end {
    my ($self, $line, $line2, $ofh) = @_;
    my ($r1_name, $r1_flag, $r1_chr, $r1_pos, $r1_ms, $r1_is, $r1_seq,) = split /\t/, $line;
    my ($r2_name, $r2_flag, $r2_chr, $r2_pos, $r2_ms, $r2_is, $r2_seq,) = split /\t/, $line2;
    $r1_is = length($r1_seq); 
    $r2_is = length($r2_seq);
    
    unless($r2_name eq $r1_name) {
        $self->error_message("Input not sorted with mates next to each other");
        die;
        #is this the right thing to do. should abort the tool here
    }
    
    if(($r1_flag & 0x0004) && ($r2_flag & 0x0004)) {
        return;
        #both unmapped, skip
    }
    elsif($r1_flag & 0x0008 && $r1_ms > 0) {
         #r1 "left" mapped. output right
         if($r2_flag & 0x0010) {
             #forward
             my $stop_position = ($r1_pos - 1);
             return unless $self->is_valid_read($r2_chr, $stop_position);
             $ofh->print("@" . $r2_name . "\n");
             $ofh->print($r2_seq . "\n");
             $ofh->print("+\t" . $r1_chr . "\t" . $stop_position );
             $ofh->print("\t" . $r1_ms . "\t" . $self->tag . "\n");
         }
         else {
             my $stop_position = ($r1_pos - 1 + $r1_is);
             return unless $self->is_valid_read($r2_chr, $stop_position);

             $ofh->print("@" . $r2_name . "\n");
             $ofh->print($self->reverse_complement($r2_seq) . "\n");
             $ofh->print("-\t" . $r1_chr . "\t" . $stop_position );
             $ofh->print("\t" . $r1_ms . "\t" . $self->tag . "\n");
             
        }
    }
    elsif($r2_flag & 0x0008 && $r2_ms >0 ) {
         #r2 "right" mapped. output left
         if($r1_flag & 0x0010) {
             #forward
             my $stop_position = ($r1_pos - 1);
             return unless $self->is_valid_read($r1_chr, $stop_position);

             $ofh->print("@" . $r1_name . "\n");
             $ofh->print($r1_seq . "\n");
             $ofh->print("+\t" . $r2_chr . "\t" . $stop_position );
             $ofh->print("\t" . $r2_ms . "\t" . $self->tag . "\n");
         }
         else {
             my $stop_position = ($r2_pos - 1 + $r2_is);
             return unless $self->is_valid_read($r1_chr, $stop_position);
             
             $ofh->print("@" . $r1_name . "\n");
             $ofh->print($self->reverse_complement($r1_seq) . "\n");
             $ofh->print("-\t" . $r2_chr . "\t" . $stop_position );
             $ofh->print("\t" . $r2_ms . "\t" . $self->tag . "\n");
             
        }
    # If the mapped read has mapping score 0, skip it
    } elsif( ($r1_flag & 0x0008 && $r1_ms == 0) || ($r2_flag & 0x0008 && $r2_ms == 0)) {
        return;
    } else {
        $self->error_message("Reached unreachable else block...something's boned.");
        die;
    }
} 
 
sub reverse_complement {
    my $self = shift;
    my $sequence = shift;
    $sequence = reverse $sequence;
    $sequence =~ tr/aAcCtTgG/tTgGaAcC/;
    return $sequence;
}

# Determines if the read is valid by looking to see if its stop position runs outside of the maximum size of the chromosome it is on
sub is_valid_read { 
    my ($self, $chromosome, $stop_position) = @_;

    my $chromosome_size = $self->chromosome_length($chromosome);

    if ( ($stop_position > 0) && ($stop_position <= $chromosome_size) ){
        return 1;
    } else {
        $self->warning_message("Ommiting read: $chromosome $stop_position > $chromosome_size or stop position < 0");
        return 0;
    }
}

sub chromosome_length {
    my ($self, $chromosome) = @_;
    
    my %chromosome_lengths = (
        1 => 247249719,
        2 => 242951149,
        3 => 199501827,
        4 => 191273063,
        5 => 180857866,
        6 => 170899992,
        7 => 158821424,
        8 => 146274826,
        9 => 140273252,
        X => 154913754,
        Y => 57772954,
        10 => 135374737,
        11 => 134452384,
        12 => 132349534,
        13 => 114142980,
        14 => 106368585,
        15 => 100338915,
        16 => 88827254,
        17 => 78774742,
        18 => 76117153,
        19 => 63811651,
        20 => 62435964,
        21 => 46944323,
        22 => 49691432,
        MT => 16571,
        NT_113887 => 3994,
        NT_113947 => 4262,
        NT_113903 => 12854,
        NT_113908 => 13036,
        NT_113940 => 19187,
        NT_113917 => 19840,
        NT_113963 => 24360,
        NT_113876 => 25994,
        NT_113950 => 28709,
        NT_113946 => 31181,
        NT_113920 => 35155,
        NT_113911 => 36148,
        NT_113907 => 37175,
        NT_113937 => 37443,
        NT_113941 => 37498,
        NT_113909 => 38914,
        NT_113921 => 39615,
        NT_113919 => 40524,
        NT_113960 => 40752,
        NT_113945 => 41001,
        NT_113879 => 42503,
        NT_113938 => 44580,
        NT_113928 => 44888,
        NT_113906 => 46082,
        NT_113904 => 50950,
        NT_113873 => 51825,
        NT_113966 => 68003,
        NT_113943 => 81310,
        NT_113914 => 90085,
        NT_113948 => 92689,
        NT_113886 => 96249,
        NT_113932 => 104388,
        NT_113929 => 105485,
        NT_113878 => 106433,
        NT_113927 => 111864,
        NT_113900 => 112804,
        NT_113918 => 113275,
        NT_113875 => 114056,
        NT_113942 => 117663,
        NT_113926 => 119514,
        NT_113934 => 120350,
        NT_113954 => 129889,
        NT_113953 => 131056,
        NT_113874 => 136815,
        NT_113883 => 137703,
        NT_113924 => 139260,
        NT_113933 => 142595,
        NT_113884 => 143068,
        NT_113890 => 143687,
        NT_113870 => 145186,
        NT_113881 => 146010,
        NT_113939 => 147354,
        NT_113956 => 150002,
        NT_113951 => 152296,
        NT_113902 => 153959,
        NT_113913 => 154740,
        NT_113958 => 158069,
        NT_113949 => 159169,
        NT_113889 => 161147,
        NT_113936 => 163628,
        NT_113957 => 166452,
        NT_113961 => 166566,
        NT_113925 => 168820,
        NT_113882 => 172475,
        NT_113916 => 173443,
        NT_113930 => 174588,
        NT_113955 => 178865,
        NT_113944 => 182567,
        NT_113901 => 182896,
        NT_113905 => 183161,
        NT_113872 => 183763,
        NT_113952 => 184355,
        NT_113912 => 185143,
        NT_113935 => 185449,
        NT_113880 => 185571,
        NT_113931 => 186078,
        NT_113923 => 186858,
        NT_113915 => 187035,
        NT_113885 => 189789,
        NT_113888 => 191469,
        NT_113871 => 197748,
        NT_113964 => 204131,
        NT_113877 => 208942,
        NT_113910 => 211638,
        NT_113962 => 217385,
        NT_113899 => 520332,
        NT_113965 => 1005289,
        NT_113898 => 1305230,
    );

    if (exists $chromosome_lengths{$chromosome}) {
        return $chromosome_lengths{$chromosome};
    } else {
        $self->error_message("No entry found for chromosome $chromosome");
        die;
    }
}

1;
