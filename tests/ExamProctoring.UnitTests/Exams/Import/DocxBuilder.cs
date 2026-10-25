using System.IO.Compression;
using System.Security;
using System.Text;

namespace ExamProctoring.UnitTests.Exams.Import;

// Builds a minimal but valid .docx in memory: a zip with [Content_Types].xml, the package relationships and word/document.xml.
// A "\n" inside a paragraph becomes a manual line break (w:br), as Shift+Enter does in Word.
internal static class DocxBuilder
{
    private const string WordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

    public static byte[] Build(IEnumerable<string> paragraphs, bool rightToLeft = false)
    {
        var body = new StringBuilder();
        foreach (var paragraph in paragraphs)
        {
            body.Append("<w:p>");
            if (rightToLeft)
                body.Append("<w:pPr><w:bidi/></w:pPr>");
            var parts = paragraph.Split('\n');
            for (var i = 0; i < parts.Length; i++)
            {
                if (i > 0)
                    body.Append("<w:r><w:br/></w:r>");
                body.Append(rightToLeft ? "<w:r><w:rPr><w:rtl/></w:rPr>" : "<w:r>")
                    .Append("<w:t xml:space=\"preserve\">").Append(SecurityElement.Escape(parts[i])).Append("</w:t></w:r>");
            }

            body.Append("</w:p>");
        }

        return Package($"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"{WordNamespace}\"><w:body>{body}</w:body></w:document>");
    }

    // A zip with the given document.xml text, for documents that need special XML (tables, tracked changes, ...).
    public static byte[] Package(string documentXml)
    {
        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            Add(archive, "[Content_Types].xml",
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
                + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
                + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
                + "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>");
            Add(archive, "_rels/.rels",
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>");
            Add(archive, "word/document.xml", documentXml);
        }

        return stream.ToArray();
    }

    private static void Add(ZipArchive archive, string name, string content)
    {
        var entry = archive.CreateEntry(name);
        using var writer = new StreamWriter(entry.Open(), new UTF8Encoding(false));
        writer.Write(content);
    }
}
