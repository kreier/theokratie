const std = @import("std");

pub fn main() !void {
    // 1. Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 2. Open and read the input CSV file
    const input_file = std.fs.cwd().openFile("bookstudy.csv", .{}) catch |err| {
        std.debug.print("Error opening bookstudy.csv: {}\n", .{err});
        return err;
    };
    defer input_file.close();

    // Read the entire file into memory (adjust max size if your CSV is massive)
    const csv_content = try input_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(csv_content);

    // 3. Create/Open the output Markdown file
    const output_file = try std.fs.cwd().createFile("bookstudy.md", .{});
    defer output_file.close();
    var writer = output_file.writer();

    // Write Markdown Table Header
    try writer.writeAll("| Start Date | Code | Title |\n");
    try writer.writeAll("| ---------- | ---- | ----- |\n");

    // 4. Parse rows
    var row_iter = std.mem.splitSequence(u8, csv_content, "\n");
    
    // Grab the header row to identify column indices dynamically
    const header_row = row_iter.next() orelse {
        std.debug.print("CSV file is empty.\n", .{});
        return;
    };

    var startdate_idx: ?usize = null;
    var code_idx: ?usize = null;
    var title_idx: ?usize = null;

    var header_col_iter = std.mem.splitSequence(u8, std.mem.trim(u8, header_row, "\r"), ",");
    var col_idx: usize = 0;
    while (header_col_iter.next()) |col| {
        const trimmed = std.mem.trim(u8, col, " ");
        if (std.mem.eql(u8, trimmed, "startdate")) startdate_idx = col_idx;
        if (std.mem.eql(u8, trimmed, "code")) code_idx = col_idx;
        if (std.mem.eql(u8, trimmed, "title")) title_idx = col_idx;
        col_idx += 1;
    }

    // Ensure we found all required columns
    const s_idx = startdate_idx orelse return error.MissingStartDateColumn;
    const c_idx = code_idx orelse return error.MissingCodeColumn;
    const t_idx = title_idx orelse return error.MissingTitleColumn;

    // Process data rows
    while (row_iter.next()) |row| {
        const trimmed_row = std.mem.trim(u8, row, "\r ");
        if (trimmed_row.len == 0) continue; // Skip empty rows

        var col_iter = std.mem.splitSequence(u8, trimmed_row, ",");
        var current_idx: usize = 0;
        
        var startdate: []const u8 = "";
        var code: []const u8 = "";
        var title: []const u8 = "";

        while (col_iter.next()) |col_val| {
            const clean_val = std.mem.trim(u8, col_val, " ");
            if (current_idx == s_idx) startdate = clean_val;
            if (current_idx == c_idx) code = clean_val;
            if (current_idx == t_idx) title = clean_val;
            current_idx += 1;
        }

        // Write row to markdown file
        try writer.print("| {s} | {s} | {s} |\n", .{ startdate, code, title });
    }

    std.debug.print("Successfully converted bookstudy.csv to bookstudy.md\n", .{});
}
