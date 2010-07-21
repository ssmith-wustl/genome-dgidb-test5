package Genome::Sample::ProjectAssignment;

use strict;
use warnings;
use Genome;

# TODO: this should be replaced by a real table filled-in after the sample
# DNA is added to a sample set, or filled earlier by a project manager.
# For now, we infer sample-project association by its presence in
# existing next-gen data.

class Genome::Sample::ProjectAssignment {
    table_name => <<'EOS',
        (
            select project.setup_id project_id, dna.dna_id sample_id
            from (
                select research_project project_name, sample_name
                from GSC.solexa_lane_summary
                union
                select research_project, nvl(sample_name,incoming_dna_name)
                from GSC.run_region_454
            ) ps
            join (
                    SELECT setup_id, setup_name 
                    FROM setup_project@oltp p 
                    JOIN setup@oltp s 
                        ON setup_id = setup_project_id 
                    WHERE project_type != 'setup project finishing' 
                        AND setup_status != 'abandoned'
            ) project on ps.project_name = project.setup_name
            join dna@oltp dna on dna.dna_name = ps.sample_name
        ) sample_project_assignment
EOS
    id_by => [
        sample  => { is => 'Genome::Sample', id_by => 'sample_id' },
        project => { is => 'Genome::Project', id_by => 'project_id' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;

