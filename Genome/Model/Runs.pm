package Genome::Model::Runs;
 
sub new{
	my $pkg = shift;
	return bless {}, $pkg;
}

our $FILESYSTEM_INFO = Genome::Model::FileSystemInfo->new();                                                                     
our $BASE_DIR = $FILESYSTEM_INFO->base_directory();                                                                              
our $RUNS_LIST_FILE = $FILESYSTEM_INFO->runs_list_filename();   

sub add_run_info {                                                                                                               
    my($class, %params) = @_;                                                                                                    
                                                                                                                                 
    my $run_number = $params{'run_number'};                                                                                      
    unless ($run_number) {                                                                                                       
        Carp::croak("run_number is a required param to add_run_info");                                                           
    }                                                                                                                            
                                                                                                                                 
    my $existing = $class->get_runs_info();                                                                                      
    if (exists $existing->{$run_number}) {                                                                                       
        Carp::confess("A run already exists with number $run_number, appending the new data to the end of the file");            
    }                                                                                                                            
                                                                                                                                 
    my $f = IO::File->new(">>$RUNS_LIST_FILE");                                                                                  
    unless ($f) {                                                                                                                
        Carp::croak("Can't open runs list file $RUNS_LIST_FILE for append: $!");                                                 
    }                                                                                                                            
                                                                                                                                 
    my $lanes_str = '';                                                                                                          
    if (ref($params{'lanes'}) eq 'ARRAY') {                                                                                      
        $lanes_str = join(',',@{$params{'lanes'}});                                                                              
    } else {                                                                                                                     
        $lanes_str = $params{'lanes'};                                                                                           
    }                                                                                                                            
                                                                                                                                 
    $f->printf('%s\t%s\t%s\t%s\n',                                                                                               
               $run_number,                                                                                                      
               $lanes_str,                                                                                                       
               $params{'bustard_path'},                                                                                          
               $params{'sample_path'},                                                                                           
             );                                                                                                                  
}   

sub get_runs_info {
    my($class) = @_;                                                                                                             
                                                                                                                                 
    my $retval = {};                                                                                                             
                                                                                                                                 
    # Format is one record per line, each line is tab seperated                                                                  
    # run number, comma sep list of lanes, bustard path for run, sample data path for run                                        
                                                                                                                                 
    my $f = IO::File->new($RUNS_LIST_FILE);                                                                                      
    unless ($f) {                                                                                                                
        Carp::croak("Can't open runs list file $RUNS_LIST_FILE for reading: $!");                                                
    }                                                                                                                            
                                                                                                                                 
    while(<$f>) {                                                                                                                
                                                                                                                                 
        s/#.*$//;  # Remove comments                                                                                             
                                                                                                                                 
        next unless (m/^\w+$/);    # skip lines with no content                                                                    
                                                                                                                                 
        my($run, $lanes, $bustard, $sample) = split(/\t/, $_);                                                                   
        my @lanes = split(/,/,$lanes);                                                                                           
                                                                                                                                 
        $retval->{$run} = { lanes => \@lanes,                                                                                    
                            bustard_path => $bustard,                                                                            
                            sample_path => $sample,                                                                              
                        }                                                                                                        
    }                                                                                                                            
                                                                                                                                 
    return $retval;                                                                                                              
}      

1;
