
package Genome::Model::Command::List::Runs;

use strict;
use warnings;

use above "Genome";
use GSC;
use GSCApp;
use Command; 
use Data::Dumper;
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;

UR::Object::Type->define(
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
    my ($self) = @_;
    
    my @irrs = Genome::RunChunk->get();
    #my @events = Genome::Model::Event->get(run_id => [map { $_->id } @irrs]);
      
    my %grouped_by_run_path;
    for (@irrs) {
        push @{$grouped_by_run_path{$_->full_path}}, $_;     
    }
    
        
    for my $path (keys %grouped_by_run_path) {
        my @out = ();
        
        my @sorted_recs = sort {$a->subset_name <=> $b->subset_name} @{$grouped_by_run_path{$path}};
        
        push @out, [
                    Term::ANSIColor::colored("Run Path:", 'red'),
                    $path
                    ];
        
        for (@sorted_recs) {
            
            my $sample = (defined $_->sample_name ? $_->sample_name : 'unknown');
            
            push @out, [Term::ANSIColor::colored("Lane:", 'blue'),
                                $_->subset_name
                        ];
            
            push @out, ["\t" . Term::ANSIColor::colored("Sample:", 'blue'),
                                $sample
                        ];
            
            # This ought to use the class definition instead of a get BUT that doesnt seem to work ATM.   
            #my @model_names = sort keys %{ { map { $_->name => 1 } $run->models } };
            if ($_->id) {
            
                my @model_names = sort keys %{  {map { $_->name => 1 }
                                     map {$_->model}
                                     Genome::Model::Event->get( run_id => $_->id )
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
                           Term::ANSIColor::colored($_->seq_id, "green")
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
    return 1; 
}

1;

