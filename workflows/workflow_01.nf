/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Check mandatory parameters
if (params.input) { csv_file = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

// set default parameter values
params.step = 'mapping'


// print parameters
log.info """\
    ======================================================================
    P I P E L I N E   N A M E
    ======================================================================
    step: ${params.input}
    samplesheet: ${params.input}
    ======================================================================
    """
    .stripIndent()


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { <process-name> } from '<relative-path>'
include { <process-name> } from '<relative-path>'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow workflow_01 {

    input_sample = extract_csv(file(csv_file))

    if (params.step == 'mapping'){

    }

    if (params.step == 'variant_calling'){

    }    

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Function to extract information (meta data + file(s)) from csv file(s)
def extract_csv(csv_file) {

    Channel.of(csv_file).splitCsv(header: true)
        // Retrieves number of lanes by grouping together by name and id and counting how many entries there are for this combination
        .map{ row ->
            //sample_count_all++
            if (!(row.name && row.id)) {
                error("Missing field in csv file header. The csv file must have fields named 'name' and 'seqId'.")
            }
            else if (row.name.contains(" ") || row.id.contains(" ")) {
                error("Invalid value in csv file. Values for 'name' and 'seqId' can not contain space.")
            }
            [ [ row.name.toString(), row.seqId.toString() ], row ]
        }.groupTuple()
        .map{ meta, rows ->
            size = rows.size()
            [ rows, size ]
        }.transpose()
        .map{ row, num_lanes -> // from here do the usual thing for csv parsing

        def meta = [:]

        // Meta data to identify samplesheet
        // Both name and seqId are mandatory
        // Several seqIds can belong to the same name
        // Combination of name and seqID should be unique
        // Name will be used as the SM: read group header value
        // Bioinformatic tools will typically merge data together from the same SM: value
        if (row.name) meta.name = row.name.toString()
        if (row.seqId)  meta.seqId  = row.seqId.toString()

        // Gather other seq meta data if provided
        if (row.seq_centre) meta.seq_centre = row.seq_centre.toString()
        else meta.seq_centre = 'NA'

        if (row.platform) meta.platform = row.platform.toString()
        else meta.platform = 'NA'

        if (row.model) meta.model = row.model.toString()
        else meta.model = 'NA'

        if (row.run_date) meta.run_date = row.run_date.toString()
        else meta.run_date = 'NA'

        if (row.library) meta.library = row.library.toString()
        else meta.library = 'NA'

        // seq_type paired or single still needs to be defined
        // flowcell id and lane number need to be extracted from fastq


        // mapping with fastq

        meta.id         = "${row.name}_X_${row.seqId}".toString()
        def fastq_1     = file(row.fastq_1, checkIfExists: true)
        def fastq_2     = file(row.fastq_2, checkIfExists: true)
        def CN          = meta.seq_center ? "CN:${meta.seq_center}\\t" : ''

        def flowcell    = flowcellLaneFromFastq(fastq_1)
        // Don't use a random element for ID, it breaks resuming
        // the below read_group needs to be revised once all meta params are accessible
        def read_group  = "\"@RG\\tID:${flowcell}.${meta.seqId}\\t${CN}PU:${flowcell}.${meta.seqId}\\tSM:${meta.name}\\tLB:${meta.library}\\tDS:${params.ref_fasta}\\tPL:${meta.platform}\\tPM:${meta.model}\\tDT:${meta.run_date}\""

        //meta.num_lanes  = num_lanes.toInteger()
        meta.read_group = read_group.toString()
        meta.data_type  = 'fastq'

        if (params.step == 'mapping') return [ meta, fastq_1, fastq_2 ]
        else {

        }
    }
}


// Parse first line of a FASTQ file, return the flowcell id and lane number.
def flowcellLaneFromFastq(path) {
    // expected format:
    // xx:yy:FLOWCELLID:LANE:... (seven fields)
    // or
    // FLOWCELLID:LANE:xx:... (five fields)
    def line
    path.withInputStream {
        InputStream gzipStream = new java.util.zip.GZIPInputStream(it)
        Reader decoder = new InputStreamReader(gzipStream, 'ASCII')
        BufferedReader buffered = new BufferedReader(decoder)
        line = buffered.readLine()
    }
    assert line.startsWith('@')
    line = line.substring(1)
    def fields = line.split(':')
    String fcid

    if (fields.size() >= 7) {
        // CASAVA 1.8+ format, from  https://support.illumina.com/help/BaseSpace_OLH_009008/Content/Source/Informatics/BS/FileFormat_FASTQ-files_swBS.htm
        // "@<instrument>:<run number>:<flowcell ID>:<lane>:<tile>:<x-pos>:<y-pos>:<UMI> <read>:<is filtered>:<control number>:<index>"
        fcid = fields[2]
    } else if (fields.size() == 5) {
        fcid = fields[0]
    }
    return fcid
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
