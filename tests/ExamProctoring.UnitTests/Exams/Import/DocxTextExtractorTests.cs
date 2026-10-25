using System.IO.Compression;
using System.Text;
using ExamProctoring.Application.Exams.Import;

namespace ExamProctoring.UnitTests.Exams.Import;

// Reading the text of a .docx: paragraphs in order, line breaks, Arabic text, tables, deleted text, and safe failure on files
// that are not Word documents.
public sealed class DocxTextExtractorTests
{
    private static DocxExtraction Extract(byte[] docx)
    {
        using var stream = new MemoryStream(docx);
        return DocxTextExtractor.Extract(stream);
    }

    private static List<string> Texts(DocxExtraction extraction) => extraction.Lines!.Select(l => l.Text).ToList();

    [Fact]
    public void ReadsParagraphsInOrder_NumbersThem_AndSkipsEmptyOnes()
    {
        var extraction = Extract(DocxBuilder.Build(["First", "", "   ", "Second"]));

        Assert.True(extraction.IsSuccess);
        Assert.Equal(["First", "Second"], Texts(extraction));
        Assert.Equal([1, 2], extraction.Lines!.Select(l => l.Number));
    }

    [Fact]
    public void ALineBreakInsideAParagraph_StartsANewLine()
    {
        Assert.Equal(["A) one", "B) two"], Texts(Extract(DocxBuilder.Build(["A) one\nB) two"]))));
    }

    [Fact]
    public void ArabicAndMixedText_IsReadWithoutChanges()
    {
        var arabic = "السؤال 1: ما هي عاصمة فرنسا؟ (Paris) — «باريس»";
        var extraction = Extract(DocxBuilder.Build([arabic], rightToLeft: true));

        Assert.Equal([arabic], Texts(extraction));
    }

    [Fact]
    public void TextInTableCells_IsRead_AndDeletedTrackedText_IsNot()
    {
        const string xml = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>"
            + "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>In a cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
            + "<w:p><w:r><w:t>Kept</w:t></w:r><w:del><w:r><w:delText>Removed</w:delText></w:r></w:del></w:p>"
            + "</w:body></w:document>";

        Assert.Equal(["In a cell", "Kept"], Texts(Extract(DocxBuilder.Package(xml))));
    }

    [Fact]
    public void ATextBox_StoredTwice_IsReadOnce()
    {
        const string xml = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
            + "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><w:body><w:p><w:r><mc:AlternateContent>"
            + "<mc:Choice><w:p><w:r><w:t>Box</w:t></w:r></w:p></mc:Choice>"
            + "<mc:Fallback><w:p><w:r><w:t>Box</w:t></w:r></w:p></mc:Fallback>"
            + "</mc:AlternateContent></w:r></w:p></w:body></w:document>";

        Assert.Equal(["Box"], Texts(Extract(DocxBuilder.Package(xml))));
    }

    [Fact]
    public void ATextFile_IsNotAWordDocument()
    {
        var extraction = Extract(Encoding.UTF8.GetBytes("Question 1: plain text"));

        Assert.False(extraction.IsSuccess);
        Assert.Equal("The file is not a valid Word (.docx) document.", extraction.Failure);
    }

    [Fact]
    public void AZipWithoutWordParts_IsRejected()
    {
        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
            new StreamWriter(archive.CreateEntry("readme.txt").Open()).Dispose();

        Assert.False(Extract(stream.ToArray()).IsSuccess);
    }

    [Fact]
    public void BrokenXml_IsRejected_NotThrown()
    {
        Assert.False(Extract(DocxBuilder.Package("<w:document xmlns:w=\"x\"><w:body><w:p>")).IsSuccess);
    }

    [Fact]
    public void ADocumentTypeDefinition_IsRejected_SoEntitiesAreNeverExpanded()
    {
        const string xml = "<?xml version=\"1.0\"?><!DOCTYPE d [<!ENTITY e SYSTEM \"file:///c:/windows/win.ini\">]>"
            + "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>&e;</w:t></w:r></w:p></w:body></w:document>";

        Assert.False(Extract(DocxBuilder.Package(xml)).IsSuccess);
    }

    [Fact]
    public void AnOversizedDocumentPart_IsRejected()
    {
        var padding = new string('x', (int)DocxTextExtractor.MaxDocumentXmlBytes + 1024);
        var xml = $"<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>{padding}</w:t></w:r></w:p></w:body></w:document>";

        var extraction = Extract(DocxBuilder.Package(xml));

        Assert.False(extraction.IsSuccess);
    }
}
