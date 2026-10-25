using System.IO.Compression;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace ExamProctoring.Application.Exams.Import;

// One line of text from the Word document, with its 1-based position among the document's non-empty lines.
public sealed record SourceLine(int Number, string Text);

// The text of a .docx, or the reason it could not be read. Failure is a short English message that is safe to show.
public sealed record DocxExtraction(IReadOnlyList<SourceLine>? Lines, string? Failure)
{
    public bool IsSuccess => Failure is null;
}

// Reads the visible text of a .docx (a zip archive of XML parts) without any Word library. Only word/document.xml is read,
// as plain XML text: macros, embedded objects, external links and images are never opened or run. The zip and the XML are
// read with hard size limits, and DTDs/external entities are disabled, so a hostile file cannot exhaust memory or read files.
public static class DocxTextExtractor
{
    public const int MaxEntries = 2000;

    // The uncompressed size of word/document.xml. A 10 MB .docx of text is far below this; a zip bomb is stopped here.
    public const long MaxDocumentXmlBytes = 20 * 1024 * 1024;

    private static readonly XNamespace W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    private static readonly XNamespace Mc = "http://schemas.openxmlformats.org/markup-compatibility/2006";

    private const string ContentTypesPart = "[Content_Types].xml";
    private const string DocumentPart = "word/document.xml";

    public static DocxExtraction Extract(Stream docx)
    {
        try
        {
            using var archive = new ZipArchive(docx, ZipArchiveMode.Read, leaveOpen: true);

            if (archive.Entries.Count > MaxEntries)
                return Fail("The Word document is too complex to read.");

            var contentTypes = archive.GetEntry(ContentTypesPart);
            var document = archive.GetEntry(DocumentPart);
            if (contentTypes is null || document is null)
                return Fail("The file is not a valid Word (.docx) document.");

            if (document.Length > MaxDocumentXmlBytes)
                return Fail("The Word document is too large to read.");

            XDocument xml;
            using (var limited = new LimitedReadStream(document.Open(), MaxDocumentXmlBytes))
            using (var reader = XmlReader.Create(limited, new XmlReaderSettings
            {
                DtdProcessing = DtdProcessing.Prohibit,
                XmlResolver = null,
                MaxCharactersInDocument = MaxDocumentXmlBytes,
                IgnoreComments = true,
                IgnoreProcessingInstructions = true,
            }))
            {
                xml = XDocument.Load(reader, LoadOptions.None);
            }

            return new DocxExtraction(ReadLines(xml), null);
        }
        catch (Exception exception) when (exception is InvalidDataException or XmlException or IOException or NotSupportedException
                                              or InvalidOperationException or ArgumentException)
        {
            return Fail("The file is not a valid Word (.docx) document.");
        }
    }

    private static DocxExtraction Fail(string message) => new(null, message);

    // Every paragraph in reading order (body, tables, text boxes), split at manual line breaks, skipping empty lines.
    private static List<SourceLine> ReadLines(XDocument xml)
    {
        var lines = new List<SourceLine>();
        var body = xml.Root?.Element(W + "body");
        if (body is null)
            return lines;

        foreach (var paragraph in body.Descendants(W + "p"))
        {
            // Word stores a text box twice (mc:Choice and mc:Fallback); read only one copy.
            if (paragraph.Ancestors(Mc + "Fallback").Any())
                continue;

            var current = new StringBuilder();
            foreach (var element in paragraph.Descendants())
            {
                // Text of a nested paragraph (for example inside a text box) belongs to that paragraph.
                if (element.Parent is null || element.Ancestors(W + "p").First() != paragraph)
                    continue;

                if (element.Name == W + "t")
                    current.Append(element.Value);
                else if (element.Name == W + "tab")
                    current.Append('\t'); // kept: a tab separates options written side by side
                else if (element.Name == W + "noBreakHyphen")
                    current.Append('-');
                else if (element.Name == W + "br" || element.Name == W + "cr")
                    Flush(current, lines);
            }

            Flush(current, lines);
        }

        return lines;
    }

    private static void Flush(StringBuilder current, List<SourceLine> lines)
    {
        var text = current.ToString().Replace(' ', ' ').Trim();
        current.Clear();
        if (text.Length > 0)
            lines.Add(new SourceLine(lines.Count + 1, text));
    }

    // Stops reading after a fixed number of bytes, whatever the zip entry claims about its own size.
    private sealed class LimitedReadStream(Stream inner, long limit) : Stream
    {
        private long _read;

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }

        public override int Read(byte[] buffer, int offset, int count)
        {
            var read = inner.Read(buffer, offset, count);
            _read += read;
            if (_read > limit)
                throw new InvalidDataException("The document part is larger than the allowed size.");
            return read;
        }

        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();

        protected override void Dispose(bool disposing)
        {
            if (disposing)
                inner.Dispose();
            base.Dispose(disposing);
        }
    }
}
