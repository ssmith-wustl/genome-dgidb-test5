
package Genome::Model::Command::List::Runs;

use strict;
use warnings;

use UR;
use GSC;
use Command; 
use Data::Dumper;
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "list all runs available for manipulation"
}

sub help_synopsis {
    return <<"EOS"
genome-model list runs
EOS
}

sub help_detail {
    return <<"EOS"
Lists all known runs
EOS
}


sub execute {
    my $self = shift;

    # find run records in lims and in the genome-model database
    # they do get or create so there should be no functional difference
    # based on what order you call these
    
    $self->_collect_solexa_run_records_from_lims();
    $self->_collect_local_run_records();
    
    # now print everything we know all pretty-like
    
    $self->_summarize_all_run_records();
 
    return 1;
}

sub _collect_solexa_run_records_from_lims {
    my $self = shift;
    
    my @gerald_pses = @{ $self->_get_all_gerald_pses() };
    
    foreach my $pse (@gerald_pses)  {
        
        my $gerald_path = $self->_get_gerald_path_from_pse($pse);
        my %lane_mapping = %{ $self->_get_dna_to_solexa_load_lane_map_for_pse($pse) };
        
        foreach my $sample (keys %lane_mapping) {
            my @lanes = split //, $lane_mapping{$sample};
            
            foreach my $lane (@lanes) {
                my $rr = Genome::Model::Command::List::Runs::InternalRunRecord->get_or_create(
                         sample_name => $sample,
                         full_path => $gerald_path,
                         date_analyzed => $pse->date_scheduled,
                         lane=>$lane);
            }
        }
    }
}

sub _collect_local_run_records {
    my $self = shift;
    
    my @runs = Genome::RunChunk->get();
    
    for my $r (@runs) {
        my $rr = Genome::Model::Command::List::Runs::InternalRunRecord->get_or_create(
            full_path=>$r,
            lane=>$r->limit_regions);
        $rr->run_chunk_id($r->id);
    }   
}

sub _summarize_all_run_records {
    my ($self) = @_;
    
    my @irrs = Genome::Model::Command::List::Runs::InternalRunRecord->get();
      
    my %grouped_by_run_path;
    for (@irrs) {
        push @{$grouped_by_run_path{$_->full_path}}, $_;     
    }
    
        
    for my $path (keys %grouped_by_run_path) {
        my @out = ();
        
        my @sorted_recs = sort {$a->lane <=> $b->lane} @{$grouped_by_run_path{$path}};
        
        my $date_analyzed = (defined $sorted_recs[0]->date_analyzed ?
                             $sorted_recs[0]->date_analyzed : 'unknown' );
        
        push @out, [
                    Term::ANSIColor::colored("Run Path:", 'red'),
                    $path
                    ];
        
        push @out, [
                   Term::ANSIColor::colored("Date Analyzed:", 'red'),
                   $date_analyzed
                   ];
                   
        for (@sorted_recs) {
            
            my $sample = (defined $_->sample_name ? $_->sample_name : 'unknown');
            
            push @out, [Term::ANSIColor::colored("Lane:", 'blue'),
                                $_->lane
                        ];
            
            push @out, ["\t" . Term::ANSIColor::colored("Sample:", 'blue'),
                                $sample
                        ];
            
        # This ought to use the class definition instead of a get BUT that doesnt seem to work ATM.   
        #my @model_names = sort keys %{ { map { $_->name => 1 } $run->models } };
        if ($_->run_chunk_id) {
        
            my @model_names = sort keys %{  {map { $_->name => 1 }
                                 map {$_->model}
                                 Genome::Model::Event->get( run_id => $_->run_chunk_id )
                                } };
            
            my $model_text = "In Model";
            
            unless( scalar(@model_names) ){
                @model_names = Term::ANSIColor::colored("none", 'magenta');
                $model_text .= ':';
            }else{
                if(scalar(@model_names) > 1){
                    $model_text .= 's:';
                }else{
                    $model_text .= ':';
                }
            }
            
            push @out, [
                       "\t" . Term::ANSIColor::colored("Run ID:", 'green'),
                       Term::ANSIColor::colored($_->run_chunk_id, "green")
                       ];
            
            push @out, [
                       "\t" . Term::ANSIColor::colored($model_text, 'red'),
                       join(", ", @model_names),
                       ];
        }
            
            
            Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );
        
            
        }
        print join( "\n",
                   map { " @$_ " }
                        @out
                   ), "\n\n\n";
       
    }
    
}

sub _get_gerald_path_from_pse{
    my ($self, $pse) = @_;
    
    my $gerald_path = GSC::PSEParam->get(
                                             param_name => 'gerald_directory',
                                             pse_id     => $pse
                                             )->param_value;
    
    return $gerald_path;
}

sub _get_dna_to_solexa_load_lane_map_for_pse{
    my ($self, $pse) = @_; 
    my $dna_his = GSC::PSE->dbh->selectall_arrayref(qq/select d.dna_name || ' (' || d.dna_type || ')', dl.location_name from process_step_executions pse
                                                     join process_steps ps on ps.ps_id = pse.ps_ps_id
                                                     join (select distinct tpse.pse_id from tpp_pse tpse 
                                                           connect by prior tpse.prior_pse_id = tpse.pse_id
                                                           start with tpse.pse_id = ?) psehist on pse.pse_id = psehist.pse_id
                                                     join dna_pse dp on dp.pse_id = pse.pse_id
                                                     join dna d on d.dna_id = dp.dna_id
                                                     join dna_location dl on dl.dl_id = dp.dl_id
                                                     and ps.pro_process_to='generate clusters'
                                                     order by dl.location_order/, {}, $pse->pse_id);

    my $lane_mapping;
    
    foreach my $row (@$dna_his) {
        my ($dna, $loc) = @$row;
        my ($laneno) = $loc =~ /lane (\d+)/;
        
        $lane_mapping->{$dna} .= $laneno;
    }
        
    return $lane_mapping;
}

sub _get_all_gerald_pses{
    my $self = shift;
        
    GSC::PSE->get(1);

    my @gerald_pses = GSC::PSE->get(
                                    ps_id => [
                                              GSC::ProcessStep->get(
                                                    process_to => 'run alignment',
                                                    purpose => 'Solexa Analysis'
                                                ) or die
                                              ],
                                    pse_status => 'completed',
                                    pse_result => 'successful'
                                    ) or die;
    
    return \@gerald_pses;
}

package Genome::Model::Command::List::Runs::InternalRunRecord;

UR::Object::Class->define(
    class_name => 'Genome::Model::Command::List::Runs::InternalRunRecord',
    english_name => 'genome model command list runs internal run record',
    id_properties => ['full_path', 'lane'],
    
    properties => [
        sample_name                => { is => 'varchar(255)', is_optional => 1 },
        full_path                  => { is => 'varchar(1000)' },
        run_chunk_id               => { is => 'integer', is_optional => 1 },
        date_analyzed              => { is => 'varchar(255)', is_optional=>1},
        lane                       => { is => 'integer'}
    ],
    
);


1;

