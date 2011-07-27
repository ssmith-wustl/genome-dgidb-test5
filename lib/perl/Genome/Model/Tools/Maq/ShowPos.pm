
package Genome::Model::Tools::Maq::ShowPos;

use strict;
use warnings; 

use IO::File;
use UR;

class Genome::Model::Tools::Maq::ShowPos {
    is => 'Genome::Model::Tools::Maq',
    has => [
        input    => { is => 'FilePath', is_optional => 1,
                      shell_args_position => 1,
                      doc => 'the name of the mapfile to view, defaults to STDIN' },
        position => { is => 'Number', is_optional => 1,
                        doc => 'show the reads at the specified position, defaults to parsing the map name' },
        refseq   => { is => 'Text', is_optional => 1,
                        doc => 'show the reads only on the specified refseq, defaults to parsing the map name' },
        separator   => { is => 'Text', is_optional => 1,
                        doc => 'instead of "pretty" format, use this field separator' },
        output   => { is => 'FilePath', is_optional => 1,
                        doc => 'the name of the mapfile to view, defaults to STDOUT' },
        header   => { is => 'Boolean', is_optional => 1, default_value => 0,
                        doc => 'show a header line' },
        cons     => { is => 'Boolean', is_optional => 1,
                        doc => 'show the consensus' },
    ],
    doc => 'show the reads supporting a given position in a friendly way',
};

sub help_brief { shift->get_class_object->doc };

sub help_synopsis {
    return <<EOS;
cat maq mapview | gmt maq show-pos -r 15 -p 9522931

EOS
}

sub execute {
    my $self = shift;
    my $show_refseq     = $self->refseq;
    my $show_position   = $self->position;;
    my $sep             = $self->separator;

    my $input           = $self->input;
    my $output          = $self->output;

    my $ret = $self->_show_pos($show_refseq, $show_position, $sep, $input,$output);
    return $ret;
}

sub _show_pos {
    my ($self, $show_refseq, $show_position, $sep, $input,$output) = @_;

    my $infh;
    if ($input) {
        if ($input =~ /^([^_]+)_(\d+)/) {
            if (not defined $show_refseq) {
                $show_refseq = $1;
            }
            if (not defined $show_position) {
                $show_position = $2;
            }
        }
        else {
            if (!defined($show_refseq) or !defined($show_position)) {
                $self->error_message("Failed to parse REFSEQ_POSITION from the map file name.  Please specify explicitly with parameters.");
                return;
            }
        }
        $infh = IO::File->new("maq mapview $input |");
        unless ($infh) {
            $self->error_message("failed to open file $input: $!");
            return;
        }
    }
    else {
        $infh = 'STDIN';
    }

    unless (defined $show_position) {
        die "no position!"
    }

    $output ||= '-'; 
    my $outfh;
    if ($sep) {
        $outfh = IO::File->new(">$output"); 
        unless ($outfh) {
            $self->error_message("failed to open $output");
            return;
        }
    }
    else {
        $sep = "\t";
        $outfh = IO::File->new("| tab2col " . ($output eq '-' ? "" : ">$output"));
        $outfh or die "failed to open pipe to tab2col";
    }

    if ($self->cons) {
        my $cns_dir = Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/';
        my $cns_filename = $cns_dir . $show_refseq . '.fasta';
        my $result = Genome::Model::Tools::ApplyDiffToFasta->execute(
            input => Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/22.fasta',
            diff  => "22.pos",
            ref_flank_file => "22.ref.fasta"
        );
        while (my $h=<>) { 
            chomp $h; 
            my ($r,$p) = ($h =~ /^\>(.*?)\|(\d+)/); $b = <>; 
            print join("\t",$r,$p,$b) 
        }
    }  
    # <$show_refseq.refbase >$show_refseq.ref"; 
    #gmt apply-diff-to-fasta --input /path/to/reference_sequences/NCBI-human-build36/22.fasta --diff 22.pos --ref-flank-file 22.refbase
    #perl -e 'while ($h=<>) { chomp $h; ($r,$p) = ($h =~ /^\>(.*?)\|(\d+)/); $b = <>; print join("\t",$r,$p,$b) }' <22.refbase >22.r
    
    while (<$infh>) {
        my @F = split(/\s+/,$_);

        my $read_name   = $F[0];
        my $refseq      = $F[1];
        next unless (!defined($show_refseq) or ($show_refseq == $refseq));

        my $position    = $F[2];
        last if $position > $show_position;
        
        my $orient      = $F[3];
        my $align_q     = $F[4];
        my $read_length = $F[13];
        my $read_seq    = $F[14];
        my $read_qual   = $F[15]; 
        
        next unless (
            !defined($show_position) 
            or (
                ($position <= $show_position) 
                and 
                (($position+$read_length-1) >= $show_position)
            )
        );

        my $o = $show_position-$F[2]+0; 
        my $b = substr($F[14],$o,1); 
        my $q = ord(substr($F[15],$o,1)); 
        my $qs = map { ord($_) } split(//,$F[15]);
        $outfh->print(join($sep,
            @F[1,2],        # chrom, pos
            $b,             # base
            $q,             # read quality
            $F[4],          # map quality
            format_pos($F[14],$o,40),
            (
                (" " x (40-$o)) 
                . substr($F[15],0,$o) 
                . " " . substr($F[15],$o,1) . " " 
                . substr ($F[15],$o+1)
            ),
            $F[3],  # orientation
            $o,     # offset of base in read
            $F[0],  # read name
        ),"\n");
    }

    sub format_pos {
        my ($str,$pos,$max) = @_;
        return (" " x ($max-$pos)) 
                . substr($str,0,$pos) 
                . " " . substr($str,$pos,1) . " " 
                . substr ($str,$pos+1)
        ;
    }
    
    return 1;
}

