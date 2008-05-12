
package Genome::Model::Command::Report::AlignmentMetrics;

use strict;
use warnings;

use above "Genome";
use Genome::Model::Command::Report;
use Genome::Model::Command::AddReads::AlignReads::Maq;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::Report::AlignmentMetrics {
    is => ['Genome::Model::Command::Report'],
    has => [
        
    ],
};

sub sub_command_sort_position { 1 }

sub help_brief {
    "report on added reads and alignment metrics"
}

sub help_synopsis {
    return <<"EOS"
genome-model report alignmnet-metrics  
                    --model-name test5
EOS
}

sub help_detail {
    return <<"EOS"
Generates a summary of all read sets added to the model, and reports on the alignment results.
EOS
}

sub execute {
    $DB::single = 1;
    my $self = shift;
    my $model = $self->model;
    
    $self->status_message("running on model " . $model->name . "\n");
    
    # cache everything we're likely to touch...
    my @all_runs = Genome::RunChunk->get(sample_name => $model->sample_name);
    my @all_events = Genome::Model::Event->get(model => $model);
    my @all_lane_summaries = GSC::RunLaneSolexa->get(sample_name => $model->sample_name);
    
    my @alignments = 
        $model->alignments('-order_by' => ['run_name','run_subset_name']);
    
    $self->status_message("Found " . scalar(@alignments) . " alignments.\n");
    
    my %tumor_fc = map { $_ => 1 } ('10150','11840','11841','11842','11845','11849','11851','11949','11950','11954','11955','11956','11957','11960','11998','12001','12002','12004','12005','12009','12010','13520','13523','13574','13580','13584','13587','13588','13607','13609','13610','13611','13612','13613','13632','13633','13644','13646','13651','1764','2016NAAXX','202BMAAXX','202CNAAXX','202FJ','202FK','202L2','202L8','202LJ','202N1','202VM','202Y0','202YB','20381','2038N','20392','20396','203VB','2040L','2040M','204TT','205B8','2089P','208AF','208DY','208GJ','208NT','2309U','3033','3076','3230','3252','3740','3753','3757','4671','5556','6143','6151','6154','6176','6179','6342','8985','8988','8990','8994','8996','8997','9074','9085','9087','9090','9128','9129','9132','FC9076','FC9130','FC9088','FC9092');
    #my %skin_fc = map { $_ => 1 } ('13519','13566','13570','13573','13577','13581','13591','13635','13643','13647','13651','14484','14492','14496','1450820','14570','14618','14619','14668','200DEAAXX','200DPAAXX','200FTAAXX','200LEAAXX','20198','202DGAAXX','202N2AAXX','202N8AAXX','202NM','202NYAAXX','204H6','204MDAAXX','2061T','2061W','2084B','2089W','208A1','208A3','208DT','208EC','208GF','208N2','20B5G','20B5L','20B60','20CJN');
    my %skin_fc = map { $_ => 1 }  ('13519', '13566', '13570', '13573', '13577', '13581', '13591', '13635', '13643', '13647', '13651', '14484', '14492', '14496', '14570', '14668', '200DPAAXX', '202DGAAXX', '204H6', '204MDAAXX', '2061T', '2061W', '2084B', '2089W', '208A1', '208A3', '208DT', '208EC', '208GF', '208N2', '20B5G', '20B5L', '20B60', '20CJN');
    
    my $treads = 0;    
    my $tunplaced = 0;
    my $tcontaminated = 0;
    my $tgood = 0;
    my $tgood_bp = 0;
    my $treads_bp = 0;
    my %runs;
    my %libraries;
    
    my @headers = (
        "SEQ_ID",
        "RUN_NAME",
        "LANE",
        "CLUSTERS",
        "READ_LENGTH",
        "DISTINCT_SEQS",
        "DUPLICATE_SEQS",
        "TOTAL_READS",
        "UNPLACED",
        "CONTAMINATED",
        "TOTAL_GOOD_READS",
        "TOTAL_BP",        
        "TOTAL_GOOD_BP",
    );
    print join("\t",@headers),"\n";
    print join("\t",map { "-" x length($_) } @headers),"\n";
    
    for my $a (@alignments) {
        my $run_name = $a->run_name;
        
        my $flow_cell_id = $a->run_short_name;
        unless ($tumor_fc{$flow_cell_id} or $skin_fc{$flow_cell_id}) {
            next;
        }
        
        my $r = $a->read_set;
        my $rls = $r->_run_lane_solexa;
        
        my $sample_name = $rls->sample_name;
        my $library_name = $rls->library_name;
        my $read_length = $rls->read_length;
        
        $libraries{$library_name}++;
        $runs{$flow_cell_id}++;
        
        my $reads;
        do {
            no warnings;
            $reads = ($a->unique_reads_across_library + $a->duplicate_reads_across_library);
            unless ($reads) {
                my @f = $a->input_read_file_paths;
                my ($wc) = grep { /total/ } `wc -l @f`;
                $wc =~ s/total//;
                $wc =~ s/\s//g;
                if ($wc % 4) {
                    warn "run $a->{id} has a line count of $wc, which is not divisible by four!"
                }
                $reads = $wc/4;
            }
        };
        
        my $unplaced = $a->poorly_aligned_read_count;
        my $contaminated = $a->contaminated_read_count;
        
        my $good = ($reads-$unplaced-$contaminated);
        
        my $reads_bp = $reads*$read_length;
        my $good_bp = $good*$read_length;
        
        no warnings;
        my @fields = (
            $r->seq_id, 
            $a->run_name, 
            $a->run_subset_name,
            $rls->clusters,
            $rls->read_length,
            $a->unique_reads_across_library, 
            $a->duplicate_reads_across_library,
            $reads,
            $unplaced,
            $contaminated,
            $good,
            $reads_bp,
            $good_bp,
        );
        
        $treads += $reads;
        $tunplaced += $unplaced;
        $tcontaminated += $contaminated;
        $tgood += $good;
        $tgood_bp += $good_bp;
        $treads_bp += $reads_bp;
        
        no warnings;
        print join("\t",@fields),"\n";
    }
    
    print "Total Libraries:\t" . scalar(keys %libraries) . "\n";
    print "Total Runs:\t" . scalar(keys %runs) . "\n";
    print "Total Reads:\t$treads\n";
    print "Total Unplaced:\t$tunplaced\n";
    print "Total Contaminated:\t$tcontaminated\n";
    print "Total Good Reads: $tgood\n";
    print "Total Good BP: $tgood_bp\n";
    print "Total BP: $treads_bp\n";
    
    return 1;
}

sub _test {
    # for testing, we're driving the underlying function...
    for my $sample_name ('H_GV-933124G-tumor1-9043g','H_GV-933124G-skin1-9017g') {
        my $model_nodups = Genome::Model->get(
            sample_name => $sample_name,
            read_aligner_name => ($sample_name =~ /skin/ ? 'maq0_6_5' : 'maq0_6_3'),
            multi_read_fragment_strategy => 'EliminateAllDuplicates',
        );
        $model_nodups or die;
        print $model_nodups->name,"\n";
        
        my $model_dups = Genome::Model->get(
            sample_name => $sample_name,
            read_aligner_name => ($sample_name =~ /skin/ ? 'maq0_6_5' : 'maq0_6_3'),
            multi_read_fragment_strategy => undef,
        );
        $model_nodups or die;
        print $model_nodups->name,"\n";
        
        __PACKAGE__->execute(model => $model_dups);
        
    }
}



1;

__END__
    if (0) {
        
        #@read_sets = Genome::RunChunk->get(run_name => { operator => "like", value => [map { '%$_%' } @run_names] });
        for my $sample_name ('H_GV-933124G-tumor1-9043g','H_GV-933124G-skin1-9017g') {
            my $model_nodups = Genome::Model->get(
                sample_name => $sample_name,
                read_aligner_name => ($sample_name =~ /skin/ ? 'maq0_6_5' : 'maq0_6_3'),
                multi_read_fragment_strategy => 'EliminateAllDuplicates',
            );
            $model_nodups or die;
            print $model_nodups->name,"\n";
            
            my $model_dups = Genome::Model->get(
                sample_name => $sample_name,
                read_aligner_name => ($sample_name =~ /skin/ ? 'maq0_6_5' : 'maq0_6_3'),
                multi_read_fragment_strategy => undef,
            );
            $model_dups or die;
            print $model_dups->name,"\n";
            
            push @models, $model_dups;
        }
    }
    
