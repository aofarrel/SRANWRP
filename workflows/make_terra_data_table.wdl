version 1.0
import "../tasks/processing_tasks.wdl" as processing

workflow Make_Terra_Data_Table {
    input {
        Array[String] headings  # 0th value must start with "entity:" and end in "_id"
        Array[Array[String]] stuff_to_write  # each inner array is one row
        String outfile
    }
    
    call processing.write_csv {
        input:
            headings = headings,
            stuff_to_write = stuff_to_write,
            outfile = outfile,
            tsv = true
    }
    
}