using System.IO.Compression;
using System.Security;
using System.Text;

namespace ExamProctoring.IntegrationTests.TestSupport;

// Builds a minimal but valid .docx in memory (a zip with the package parts and word/document.xml) for upload tests.
internal static class DocxBuilder
{
    public static byte[] Build(IEnumerable<string> paragraphs, bool rightToLeft = false)
    {
        var body = new StringBuilder();
        foreach (var paragraph in paragraphs)
        {
            body.Append("<w:p>");
            if (rightToLeft)
                body.Append("<w:pPr><w:bidi/></w:pPr>");
            body.Append(rightToLeft ? "<w:r><w:rPr><w:rtl/></w:rPr>" : "<w:r>")
                .Append("<w:t xml:space=\"preserve\">").Append(SecurityElement.Escape(paragraph)).Append("</w:t></w:r></w:p>");
        }

        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            Add(archive, "[Content_Types].xml",
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
                + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
                + "<Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>");
            Add(archive, "word/document.xml",
                "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
                + $"<w:body>{body}</w:body></w:document>");
        }

        return stream.ToArray();
    }

    private static void Add(ZipArchive archive, string name, string content)
    {
        using var writer = new StreamWriter(archive.CreateEntry(name).Open(), new UTF8Encoding(false));
        writer.Write(content);
    }
}
