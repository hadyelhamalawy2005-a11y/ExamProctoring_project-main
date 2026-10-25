using ExamProctoring.Api.Authorization;
using ExamProctoring.Api.Errors;
using ExamProctoring.Application.Exams;
using ExamProctoring.Application.Exams.Import;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ExamProctoring.Api.Controllers;

// Importing questions from a Word (.docx) file, in two steps. Instructors only; Admins and Students get 403.
[ApiController]
[Route("api")]
[Authorize(Policy = AuthorizationPolicies.InstructorOnly)]
public sealed class QuestionImportController(QuestionImportService importService, QuestionService questionService) : ControllerBase
{
    // Step 1: reads the uploaded .docx and returns the questions it contains, with any problems. Nothing is saved.
    // Multipart form with one file field named "file" (at most 10 MB). A file problem is 400 validation_failed on "file";
    // a request that is too large is 413. Problems inside the document are in the 200 body (isValid, issues).
    [HttpPost("questions/import/preview")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(QuestionImportLimits.MaxRequestBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = QuestionImportLimits.MaxRequestBytes)]
    [ProducesResponseType<QuestionImportPreviewResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status413PayloadTooLarge, "application/problem+json")]
    public async Task<IActionResult> PreviewImport(IFormFile? file, CancellationToken cancellationToken)
    {
        // Same answer as a body over the request limit (see GlobalExceptionHandler): 413 ProblemDetails.
        if (file is { Length: > QuestionImportLimits.MaxFileBytes })
            throw new BadHttpRequestException("The file is larger than 10 MB.", StatusCodes.Status413PayloadTooLarge);

        await using var content = file?.OpenReadStream();
        var result = await importService.PreviewAsync(content, file?.FileName, file?.Length ?? 0, cancellationToken);

        return result.IsSuccess ? Ok(result.Value) : this.ToProblem(result.Error!);
    }

    // Step 2: saves the reviewed questions at the end of the exam, all or none (same rules as POST /api/exams/{id}/questions
    // for every question). Same 404 / 409 answers as adding a single question.
    [HttpPost("exams/{examId}/questions/import")]
    [ProducesResponseType<QuestionListResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict, "application/problem+json")]
    public async Task<IActionResult> ConfirmImport(string examId, QuestionImportRequest request, CancellationToken cancellationToken)
    {
        var result = await questionService.ImportAsync(examId, request, cancellationToken);

        return result.IsSuccess
            ? StatusCode(StatusCodes.Status201Created, result.Value)
            : this.ToProblem(result.Error!);
    }
}
