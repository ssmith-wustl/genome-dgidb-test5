package Genome::Model::Tools::DetectVariants::Dispatcher::Version2;

use strict;
use warnings;

use Data::Dumper;
use JSON;
use Genome;
use Parse::RecDescent;

# grammar for parsing strategy rules
# sample valid input:
# samtools v1 <-q -a "foo"> filtered by myfilter v1 <-q>, myotherfilter v2 <> || var-scan v1 <>

my $grammar = q{
    startrule: combination end
        { $item[1]; }
    | <error>

    end: /^\Z/

    combination: intersection
                { $item[1]; }
    | union
                { $item[1]; }
    | single
                { $item[1]; }
    | <error>
    
    parenthetical: "(" combination ")"
                { $item[2]; }
                
    intersection: single "&&" combination
                { $return = { intersect => [$item[1], $item[3] ] }; }
    
    union: single "||" combination
                { $return = { union => [ $item[1], $item[3] ] }; }
    
    single: parenthetical
                { $item[1]; }
    | "somatic " strategy
                { $item[2]->{name} = "somatic $item[2]->{name}"; $item[2]; }
    | strategy
                { $item[1]; }
    
    strategy: program_spec "filtered by" filter_list
                { $return = { detector => {%{$item[1]}, filters => $item[3]} }; }
    | program_spec 
                { $return = { detector => {%{$item[1]}, filters => undef} }; }
    | <error>

    filter_list: program_spec "," filter_list
                { $return = [$item[1], @{$item[3]}]; }
    | program_spec
                { $return = [$item[1]]; }

    word: /([\w\.-]|\\\\)+/ { $return = $item[1]; }
    name: word { $return = $item[1]; }
    version: word { $return = $item[1]; }
    | <error>

    params: {
                my $txt = extract_codeblock($text, '{}');
                $return = eval $txt;
                if ($@ or ref $return ne "HASH") {
                    die("Failed to turn string '$txt' into perl hashref: $@.");
                }
            } 
    | <error>


    program_spec: name version params
                { $return = {
                    name => $item[1],
                    version => $item[2],
                    params => $item[3],
                    };
                }
};

class Genome::Model::Tools::DetectVariants::Dispatcher::Version2 {
    is => ['Genome::Model::Tools::DetectVariants::Somatic'],
    has_optional => [
        snv_detector_strategy => {
            is => "String",
            doc => 'The variant detector strategy to use for finding SNPs',
        },
        indel_detector_strategy => {
            is => "String",
            doc => 'The variant detector strategy to use for finding indels',
        },
        sv_detector_strategy => {
            is => "String",
            doc => 'The variant detector strategy to use for finding SVs',
        },
        control_aligned_reads_input => {
            doc => 'Location of the control aligned reads file to which the input aligned reads file should be compared (if using a detector that needs one)'
        },
    ],
    has_constant_optional => [
        version => {}, #We need separate versions for the dispatcher
    ],
    has_constant => [
        variant_types => {
            is => 'ARRAY',
            value => [('snv', 'indel', 'sv')],
        },
        #These can't be turned off--just pass no detector name to skip
        detect_snvs => { value => 1 },
        detect_indels => { value => 1 },
        detect_svs => { value => 1 },
    ],
    doc => 'This tool is used to handle delegating variant detection to one or more specified tools and combining the results',
};

sub help_brief {
    "A dispatcher for variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants dispatcher ...
EOS
} #TODO Fill in this synopsis with a few examples

sub help_detail {
    return <<EOS 
A variant detector(s) specified under snv-detector, indel-detector, or sv-detector must have a corresponding module under `gmt detect-variants`.
EOS
}

sub _should_skip_execution {
    my $self = shift;
    
    for my $variant_type (@{ $self->variant_types }) {
        my $name_property = $variant_type . '_detector_strategy';
        
        return if defined $self->$name_property;
    }
    
    $self->status_message('No variant detectors specified.');
    return $self->SUPER::_should_skip_execution;
}

sub strategy {
    my $self = shift;

    my $detector_trees = {};
    my $detectors_to_run = {};
    
    # Build up detection request
    for my $variant_type (@{ $self->variant_types }) {
        my $name_property = $variant_type . '_detector_strategy';
        
        if($self->$name_property) {
            my $detector_tree = $self->parse_detector_strategy($self->$name_property);
            
            $detector_trees->{$variant_type} = $detector_tree;
            $self->build_detector_list($detector_tree, $detectors_to_run, $variant_type);
        }
    } 

    return ($detector_trees);
}

sub _detect_variants {
    my $self = shift;

    my $strategy = $self->strategy;
    die "Not implemented yet, awaiting workflow code. The strategy looks like: " .  Dumper($strategy);
}

sub _verify_inputs {
    my $self = shift;
    
    #Skip the somatic checks since we might not be running a somatic detector.  (If we are the checks will be performed then.)
    return $self->Genome::Model::Tools::DetectVariants::_verify_inputs;
}

sub calculate_detector_output_directory {
    my $self = shift;
    my ($detector, $version, $param_list) = @_;
    
    my $subdirectory = join('-', $detector, $version, $param_list);
    
    return $self->output_directory . '/' . Genome::Utility::Text::sanitize_string_for_filesystem($subdirectory);
}

sub parse_detector_strategy {
    my $self = shift;
    my $string = shift;
    
    return unless $string;
    
    my $parser = $self->parser;
    
    my $result = $parser->startrule($string);
    
    unless($result) {
        $self->error_message('Failed to interpret detector string from ' . $string);
        die($self->error_message);
    }
    
    return $result;
}

sub is_valid_detector {
    my $self = shift;
    my $detector_class = shift;
    
    return if $detector_class eq $self->class; #Don't nest the dispatcher!
    
    my $detector_class_base = 'Genome::Model::Tools::DetectVariants';
    return $detector_class->isa($detector_class_base);
}

sub detector_class {
    my $self = shift;
    my $detector = shift;
    
    $detector = join ("", map { ucfirst(lc($_)) } split(/-/,$detector) ); #Convert things like "foo-bar" to "FooBar"
    
    my $detector_class_base = 'Genome::Model::Tools::DetectVariants';
    my $detector_class = join('::', ($detector_class_base, $detector));
    
    return $detector_class;
}

sub parser {
    my $self = shift;
    
    my $parser = Parse::RecDescent->new($grammar)
        or die('Failed to construct parser from grammar.');
        
    return $parser;
}

# return value is a hash like:
# { samtools => { r453 => {snv => ['']}}, 'var-scan' => { '' => { snv => ['']} }, maq => { '0.7.1' => { snv => ['a'] } }}
sub build_detector_list {
    my $self = shift;
    my ($detector_tree, $detector_list, $detector_type) = @_;
    
    #Just recursively keep looking for detectors
    my $branch_case = sub {
        my $self = shift;
        my ($combination, $subtrees, $branch_case, $leaf_case, $detector_list, $detector_type) = @_;
        
        for my $subtree (@$subtrees) {
            $self->walk_tree($subtree, $branch_case, $leaf_case, $detector_list, $detector_type);
        }
        
        return $detector_list;
    };
    
    #We found the detector we're looking for
    my $leaf_case = sub {
        my $self = shift;
        my ($detector, $branch_case, $leaf_case, $detector_list, $detector_type) = @_;

        my $name = $detector->{name};
        my $version = $detector->{version};
        my $params = $detector->{params};
        my $params_str = to_json($params);
        
        #Do not push duplicate entries
        unless(exists($detector_list->{$name}{$version}{$detector_type}) and
               grep(to_json($_) eq $params_str, @{ $detector_list->{$name}{$version}{$detector_type} })) {
        
            push @{ $detector_list->{$name}{$version}{$detector_type} }, $params;
        }
        
        return $detector_list;
    };
    
    return $self->walk_tree($detector_tree, $branch_case, $leaf_case, $detector_list, $detector_type);
}

#A generic walk of the tree structure produced by the parser--takes two subs $branch_case and $leaf_case to handle the specific logic of the step
sub walk_tree {
    my $self = shift;
    my ($detector_tree, $branch_case, $leaf_case, @params) = @_;
    
    unless($detector_tree) {
        $self->error_message('No parsed detector tree provided.');
        die($self->error_message);
    }
    
    my @keys = keys %$detector_tree;
    
    #There should always be exactly one outer rule (or detector)
    unless(scalar @keys eq 1) {
        $self->error_message('Unexpected data structure encountered!  There were ' . scalar(@keys) . ' keys');
        die($self->error_message);
    }
    
    my $key = $keys[0];
    
    #Case One:  We're somewhere in the middle of the data-structure--we need to combine some results
    if($key eq 'intersect' or $key eq 'union') {
        my $value = $detector_tree->{$key};
        
        unless(ref $value eq 'ARRAY') {
            $self->error_message('Unexpected data structure encountered! I really wanted an ARRAY, not ' . (ref($value)||$value) );
            die($self->error_message);
        }
        
        return $branch_case->($self, $key, $value, $branch_case, $leaf_case, @params);
    } elsif($key eq 'detector') {
        my $value = $detector_tree->{$key};

        unless(ref $value eq 'HASH') {
            $self->error_message('Unexpected data structure encountered! I really wanted a HASH, not ' . (ref($value)||$value) );
            die($self->error_message);
        }
        return $leaf_case->($self, $value, $branch_case, $leaf_case, @params);
    } else {
        $self->error_message("Unknown key in detector hash: $key");
        die($self->error_message);
    }
    #Case Two: Otherwise the key should be the a detector specification hash, 
}

1;
