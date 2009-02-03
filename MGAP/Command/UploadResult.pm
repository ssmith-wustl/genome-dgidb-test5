package MGAP::Command::UploadResult;

use strict;
use warnings;

use BAP::DB::SequenceSet;
use BAP::DB::Sequence;
use BAP::DB::tRNAGene;

use Workflow;

class MGAP::Command::UploadResult {
    is => ['MGAP::Command'],
    has => [
        dev => { is => 'SCALAR', doc => "if true set $BAP::DB::DBI::db_env = 'dev'" },
        seq_set_id => { is => 'SCALAR', doc => 'identifies a whole assembly' },
        bio_seq_features => { is => 'ARRAY', doc => 'array of Bio::Seq::Feature' },
    ],
};

operation_io MGAP::Command::UploadResult {
    input  => [ 'bio_seq_features', 'seq_set_id', 'dev' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Store input gene predictions in the MGAP schema";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    
    my $self = shift;
    
    
    if ($self->dev()) {
        $BAP::DB::DBI::db_env = 'dev'; 
    }
    
    my $sequence_set_id = $self->seq_set_id();

    my $sequence_set = BAP::DB::SequenceSet->retrieve($sequence_set_id);

    my @sequences = $sequence_set->sequences();

    foreach my $sequence (@sequences) {

        my @coding_genes = $sequence->coding_genes();
        my @trna_genes   = $sequence->trna_genes();
        my @rna_genes    = $sequence->rna_genes();
        
        foreach my $gene (
                          @coding_genes,
                          @trna_genes,
                          @rna_genes
                      ) { $gene->delete(); }
        
    }
    
    $self->{_gene_count} = { };
    
    my %features            = ( );
    
    foreach my $ref (@{$self->bio_seq_features()}) {
        foreach my $feature (@{$ref}) {
            push @{$features{$feature->seq_id()}}, $feature;
        }
    }
    
    foreach my $seq_id (keys %features) {

        $self->{_gene_count}{$seq_id}{trnascan} = 0;
        $self->{_gene_count}{$seq_id}{rnammer} = 0;
        $self->{_gene_count}{$seq_id}{rfam} = 0;
        
        my $sequence = BAP::DB::Sequence->retrieve(
                                                   sequence_set_id => $sequence_set_id,
                                                   sequence_name   => $seq_id,
                                               );

        my $sequence_id = $sequence->sequence_id();

        my $seq_obj = Bio::Seq->new(
                                    -seq => $sequence->sequence_string(),
                                    -id  => $sequence->sequence_name(),
                                );
        
        
        my @features = @{$features{$seq_id}};
        
        foreach my $feature (@features) {
            
            my $source = $feature->source_tag();
            
            if ($source eq 'Glimmer_3.X') {
                $self->{_gene_count}{$seq_id}{glimmer3}++;
                $self->_store_glimmer_genemark($sequence_id, $feature, $seq_obj);
            }
            elsif ($source eq 'Genemark.hmm.pro') {
                ($feature) = $feature->exons();
                $self->{_gene_count}{$seq_id}{genemark}++;
                $self->_store_glimmer_genemark($sequence_id, $feature, $seq_obj);
            }
            elsif ($source eq 'tRNAscan-SE') {
                $self->{_gene_count}{$seq_id}{trnascan}++;
                $self->_store_trnascan($sequence_id, $feature);
            }
            elsif ($source =~ /^RNAmmer/) {
                $self->{_gene_count}{$seq_id}{rnammer}++;
                $self->_store_rnammer($sequence_id, $feature);
            }
            elsif ($source eq 'Infernal' ) {
                $self->{_gene_count}{$seq_id}{rfam}++;
                $self->_store_rfamscan($sequence_id, $feature);
            }
            
        }
        
    }
    
    BAP::DB::DBI->dbi_commit();
    
    return 1;
    
}

sub _store_glimmer_genemark {

    my ($self, $sequence_id, $feature, $seq_obj) = @_;

    $DB::single=1;
    my $gene_name;
    my $source;
    
    if ($feature->source_tag() =~ /glimmer/i) { 
        $source = 'glimmer3';
        $gene_name = join '.', $feature->seq_id(), 'Glimmer3', $self->{_gene_count}{$feature->seq_id()}{'glimmer3'};
    }
    elsif ($feature->source_tag() =~ /genemark/i) {
        $source = 'genemark';
        $gene_name = join '.', $feature->seq_id(), 'GeneMark', $self->{_gene_count}{$feature->seq_id()}{'genemark'};
    }
        
    my $strand   = $feature->strand();
    my $start    = $feature->start();
    my $end      = $feature->end();
    my $location = $feature->location();
    
    my $internal_stops = 0;
    my $fragment       = 0;
    my $missing_start  = 0;
    my $missing_stop   = 0;
    my $wraparound     = 0;
    
    if ($feature->has_tag('wraparound'))         { $wraparound = 1; }
    if ($location->isa('Bio::Location::Fuzzy'))  { $fragment   = 1; }
    
    # Fractional codons mean the reading frame is horked, and presently the
    # upstream parsers aren't passing along frame info, so we have to do our best to
    # reverse engineer the correct one
    unless (((abs($end - $start) + 1) % 3) == 0) {
        
        # Without a Bio::Location::Fuzzy, we cannot determine the correct reading frame
        unless ($location->isa('Bio::Location::Fuzzy')) {
            die "length is not a multiple of 3 and location is not fuzzy";
        }
        
        my $fuzzy_start    = 0;
        my $fuzzy_end      = 0;
        my $extra_bases    = ((abs($end - $start) + 1) % 3);
        my $start_pos_type = $location->start_pos_type();
        my $end_pos_type   = $location->end_pos_type();
        
        if (
            $start_pos_type eq 'BEFORE' ||
            $start_pos_type eq 'AFTER'
        ) {
            $fuzzy_start = 1;
        }
        
        if (
            $end_pos_type eq 'AFTER' ||
            $end_pos_type eq 'BEFORE'
        ) {
            $fuzzy_end = 1;
        }
        
        # We have to have one inexact end to shave bases off
        unless ($fuzzy_start || $fuzzy_end) {
            die "location is fuzzy, but start and stop are both exact";
        }
        
        # With two inexact ends, there is no hope of restoring the correct reading frame
        # intended by the predictor (we don't have an exact anchor point)
        if ($fuzzy_start && $fuzzy_end) {
            die "both start and end are fuzzy";
        }
        
        if ($fuzzy_start) {
            if ($start_pos_type eq 'BEFORE') {
                $start += $extra_bases;
            }
            if ($start_pos_type eq 'AFTER') {
                $start -= $extra_bases;
            }
        }
        
        if ($fuzzy_end) {
            if ($end_pos_type eq 'BEFORE') {
                $end += $extra_bases;
            }
            if ($end_pos_type eq 'AFTER') {
                $end -= $extra_bases;
            }
        }
        
    }
    
    # The GeneMark parser emits SeqFeatures for minus strand genes with start < end,
    # the Glimmer parser emits SeqFeatures for minus strand genes with start > end,
    # now that we're done screwing with them, flip them to be consistent
    if ($start > $end) { ($start, $end) = ($end, $start); }
    
    my $gene_seq_obj    = $seq_obj->trunc($start, $end);
    
    unless ($strand > 0) {
        $gene_seq_obj = $gene_seq_obj->revcom();
    } 
    
    my $protein_seq_obj = $gene_seq_obj->translate();
    
    if ($protein_seq_obj->seq() =~ /\*.+/) { $internal_stops = 1; }
    
    unless ($protein_seq_obj->seq() =~ /\*$/) { $missing_stop = 1; }
    
    my $first_codon = substr($gene_seq_obj->seq(), 0, 3);
    
    unless ($first_codon =~ /tg$/i) { $missing_start = 1; }
    
    my $coding_gene_obj = BAP::DB::CodingGene->insert({
                                                       gene_name       => $gene_name,
                                                       sequence_id     => $sequence_id,
                                                       start           => $start,
                                                       end             => $end,
                                                       strand          => $strand,
                                                       source          => $source,
                                                       sequence_string => $gene_seq_obj->seq(),
                                                       internal_stops  => $internal_stops,
                                                       missing_start   => $missing_start,
                                                       missing_stop    => $missing_stop,
                                                       fragment        => $fragment,
                                                       wraparound      => $wraparound,
                                                       phase_0         => 1,
                                                       phase_1         => 0,
                                                       phase_2         => 0,
                                                       phase_3         => 0,
                                                       phase_4         => 0,
                                                       phase_5         => 0,
                                                   });
    
    my $protein_name = $gene_name;
    my $gene_id = $coding_gene_obj->gene_id();
    
    BAP::DB::Protein->insert({
                              protein_name    => $protein_name,
                              gene_id         => $gene_id,
                              sequence_string => $protein_seq_obj->seq(),
                              internal_stops  => $internal_stops,
                          });
    
}

sub _store_trnascan {
    
    my ($self, $sequence_id, $feature) = @_;
    
    
    my $gene_name = join('.', $feature->seq_id(), (join('', 't', $self->{_gene_count}{$feature->seq_id()}{'trnascan'})));
    my ($codon)   = $feature->each_tag_value('Codon');
    my ($aa)      = $feature->each_tag_value('AminoAcid');
    
    BAP::DB::tRNAGene->insert({
                               gene_name   => $gene_name,
                               sequence_id => $sequence_id,
                               start       => $feature->start(),
                               end         => $feature->end(),
                               strand      => $feature->strand(),
                               source      => 'trnascan',
                               score       => $feature->score(),
                               codon       => $codon,
                               aa          => $aa,
                           });
    
}

sub _store_rnammer {

    my ($self, $sequence_id, $feature) = @_;

    
    my $gene_name     = join '.', $feature->seq_id(), 'rnammer', $self->{_gene_count}{$feature->seq_id()}{'rnammer'};
    my $score         = $feature->score();
    my ($description) = $feature->each_tag_value('group');
    
    BAP::DB::RNAGene->insert({
                              gene_name   => $gene_name,
                              sequence_id => $sequence_id,
                              start       => $feature->start(),
                              end         => $feature->end(),
                              acc         => 'RNAmmer',
                              desc        => $description,
                              strand      => $feature->strand(),
                              source      => 'rnammer',
                              score       => $score,
                          });
    
}

sub _store_rfamscan {

    my ($self, $sequence_id, $feature) = @_;


    my $gene_name          = join '.', $feature->seq_id(), 'rfam', $self->{_gene_count}{$feature->seq_id()}{'rfam'};
    my $score              = $feature->score();
    my ($rfam_accession)   = $feature->each_tag_value('acc');
    my ($rfam_description) = $feature->each_tag_value('id');
    
    unless (($score <= 50) || ($rfam_description =~ /tRNA/i)) {
        
        BAP::DB::RNAGene->insert({
                                  gene_name   => $gene_name,
                                  sequence_id => $sequence_id,
                                  start       => $feature->start(),
                                  end         => $feature->end(),
                                  acc         => $rfam_accession,
                                  desc        => $rfam_description,
                                  strand      => $feature->strand(),
                                  source      => 'rfam',
                                  score       => $score,
                              });
        
    }
    
}


1;
