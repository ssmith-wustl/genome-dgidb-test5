package Genome::Model::Tools::Annotate::Adaptor::Sniper;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Annotate::Adaptor::Sniper {
    is => 'Genome::Model::Tools::Annotate',
    has => [
        somatic_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The somatic file output from sniper to be adapted',
        },
        output_file => {
            is => 'Text',
            is_input => 1,
            is_output => 1,
            doc => "Store output in the specified file instead of sending it to STDOUT."
        },
    ],
};

sub help_brief {
    "Converts somatic sniper output into a gt annotate transcript-variants friendly input format",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools annotate adaptor sniper ...    
EOS
}

sub help_detail {                           
    return <<EOS 
Converts somatic sniper output into a gt annotate transcript-variants friendly input format
EOS
}

# For now assume we have a somatic file already made from the normal and tumor bam files... separate tool for this perhaps
sub execute {
    my $self = shift;

    unless (-s $self->somatic_file) {
        $self->error_message("blahhhhhhhhhhh YOU SUPPLY A FILE PLEASE");
        die;
    }
    my $somatic_fh = IO::File->new($self->somatic_file);

    # establish the output handle for the transcript variants
    my $output_fh;
    if (my $output_file = $self->output_file) {
        $output_fh = $self->_create_file($output_file);
    }
    else {
        $output_fh = 'STDOUT';
    }

    my @return;   
    while (my $line=$somatic_fh->getline) {
        chomp $line;
        if($line =~ m/\*/) {
            #INDELOL!!!
            @return = $self->parse_indel_line($line);
            for my $ret (@return) {
                $output_fh->print(join("\t",@{$ret}) . "\n");
            }
       }
       else { #CONSNPTION FIT!
            my ($chr, $start, $ref_base, $variant_base, $somatic_score, $consensus_quality, $snp_quality, $max_map_q, $depth_tumor, $depth_normal) = split("\t", $line);
            $output_fh->print("$chr\t$start\t$start\t$ref_base\t$variant_base\tSNP\t$somatic_score\t$consensus_quality\t$snp_quality\t$max_map_q\t$depth_tumor\t$depth_normal\n");
        }
    }
}


sub parse_indel_line {
    my $self=shift;
    my ($line) = @_;
    my @return;
    #$self->status_message("(SEARCHING FOR: $line)");

    my %indel1;
    my %indel2;
    my ($chr,
        $start_pos,
        $star, 
        $somatic_score,
    );
    my @rest_of_fields;
    ($chr,
        $start_pos,
        $star, 
        $somatic_score,
        $indel1{'sequence'},
        $indel2{'sequence'}, 
        $indel1{'length'},
        $indel2{'length'},
        @rest_of_fields
    ) = split /\s+/, $line; 
    my @indels;
    push(@indels, \%indel1);
    push(@indels, \%indel2);
    for my $indel(@indels) {
        
        if ($indel->{'sequence'} eq '*') { next; }
        my $hash;
        my $stop_pos;
        my $start;
        if($indel->{'length'} < 0) {
            #it's a deletion!
            $hash->{variation_type}='DEL';
            $start= $start_pos+1;
            $stop_pos = $start_pos + abs($indel->{'length'});
            $hash->{reference}=$indel->{'sequence'};
            $hash->{variant}=0;
        }
        else {
            #it's an insertion
            $hash->{variation_type}='INS';
            $start=$start_pos;
            $stop_pos = $start_pos+1;
            $hash->{reference}=0;
            $hash->{variant}=$indel->{'sequence'};

        }

        $hash->{chromosome}=$chr;
        $hash->{start}=$start;
        $hash->{stop}=$stop_pos;
        #$hash->{num_reads}=$num_reads_across;
        push @return, [@$hash{"chromosome","start","stop","reference","variant","variation_type"}, $somatic_score, @rest_of_fields];
    }
    return @return;
}
1;

