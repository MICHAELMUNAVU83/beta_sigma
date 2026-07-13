# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigma.OpenAI do
  @moduledoc false

  require Logger

  @project_brief_template_path Path.expand("../../project_brief_template.md", __DIR__)
  @podcast_base_template_path Path.expand("../../podcast_base.md", __DIR__)

  @default_podcast_base_template """
  ## Segment 1: Cold Open (2-3 min)
  Purpose: Hook the audience with the guest's most interesting tension, contrarian belief, or defining lesson.
  - What is the sharpest lesson you've learned about building engineering teams?
  - Was there a moment when your view of leadership changed?

  ## Segment 2: Origin Story (6-8 min)
  Purpose: Establish the guest's background, company context, and what shaped their current approach.
  - What path led you into this role?
  - What makes your company's engineering environment distinctive right now?

  ## Segment 3: Tech Stack Decisions (8-10 min)
  Purpose: Explore architecture, tools, tradeoffs, and how technical choices connect to business goals.
  - Which technical decisions have mattered most recently?
  - How do you balance speed, quality, and maintainability?

  ## Segment 4: Building the Team (8-10 min)
  Purpose: Understand hiring, onboarding, team design, and how the culture is reinforced day to day.
  - What do you optimize for when growing the team?
  - How do you keep standards high as the team changes?

  ## Segment 5: Staying Great Under Pressure (6-8 min)
  Purpose: Surface how the team handles incidents, ambiguity, competing priorities, and difficult tradeoffs.
  - What kind of pressure reveals the health of an engineering team?
  - How do you respond when plans meet reality?

  ## Segment 6: Rapid Fire (3-4 min)
  Purpose: End with concise, memorable insights and practical advice.
  - What practice would you recommend to other engineering leaders?
  - What is one mistake teams should avoid repeating?

  ## Segment 7: Close (2-3 min)
  Purpose: Wrap up with final reflections and where listeners can follow the guest's work.
  - What should listeners keep an eye on next?
  - Where can people find you and your work?
  """

  def send_request_to_openai(context, prompt, opts \\ []) do
    api_url = "https://api.openai.com/v1/chat/completions"
    api_key = api_key()

    # Voice calls can pass a smaller max_tokens for lower latency (e.g. 150 for ~25 words)
    max_tokens = Keyword.get(opts, :max_tokens, 4000)

    model = Keyword.get(opts, :model, "gpt-4o-mini")

    body = %{
      "model" => model,
      "messages" => [
        %{
          "role" => "system",
          "content" => context
        },
        %{"role" => "user", "content" => prompt}
      ],
      "temperature" => 0.5,
      "max_tokens" => max_tokens
    }

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      req_options = [
        headers: headers,
        json: body,
        retry: :transient,
        max_retries: 10,
        receive_timeout: 60_000
      ]

      case Req.post(api_url, req_options) do
        {:ok, %{status: 200, body: response_body}} ->
          case response_body do
            %{"choices" => [%{"message" => %{"content" => content}} | _]}
            when is_binary(content) ->
              {:ok, content}

            %{"choices" => []} ->
              {:error, :empty_response}

            _unexpected ->
              Logger.warning("Unexpected OpenAI success response: #{inspect(response_body)}")
              {:error, :invalid_response}
          end

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI error response: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  def send_request_to_openai_no_max_tokens(context, prompt, opts \\ []) do
    api_url = "https://api.openai.com/v1/chat/completions"
    api_key = api_key()

    model = Keyword.get(opts, :model, "gpt-4o-mini")

    body = %{
      "model" => model,
      "messages" => [
        %{
          "role" => "system",
          "content" => context
        },
        %{"role" => "user", "content" => prompt}
      ],
      "temperature" => 0.3
    }

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      req_options = [
        headers: headers,
        json: body,
        retry: :transient,
        max_retries: 10,
        receive_timeout: 60_000
      ]

      case Req.post(api_url, req_options) do
        {:ok, %{status: 200, body: response_body}} ->
          case response_body do
            %{"choices" => [%{"message" => %{"content" => content}} | _]}
            when is_binary(content) ->
              {:ok, content}

            %{"choices" => []} ->
              {:error, :empty_response}

            _unexpected ->
              Logger.warning("Unexpected OpenAI success response: #{inspect(response_body)}")
              {:error, :invalid_response}
          end

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI error response: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  @doc """
  Sends a multimodal chat request. `user_content` must be a list of OpenAI
  content parts (`%{"type" => "text", ...}` or `%{"type" => "image_url", ...}`).
  """
  def send_vision_request_to_openai(context, user_content, opts \\ [])
      when is_list(user_content) do
    api_url = "https://api.openai.com/v1/chat/completions"
    api_key = api_key()

    max_tokens = Keyword.get(opts, :max_tokens, 1500)
    model = Keyword.get(opts, :model, "gpt-4o-mini")

    body = %{
      "model" => model,
      "messages" => [
        %{"role" => "system", "content" => context},
        %{"role" => "user", "content" => user_content}
      ],
      "temperature" => 0.2,
      "max_tokens" => max_tokens,
      "response_format" => %{"type" => "json_object"}
    }

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      req_options = [
        headers: headers,
        json: body,
        retry: :transient,
        max_retries: 3,
        receive_timeout: 120_000
      ]

      case Req.post(api_url, req_options) do
        {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}}
        when is_binary(content) ->
          {:ok, content}

        {:ok, %{status: 200, body: response_body}} ->
          Logger.warning("Unexpected OpenAI vision response: #{inspect(response_body)}")
          {:error, :invalid_response}

        {:ok, %{status: status, body: response_body}} ->
          Logger.warning("OpenAI vision error response: #{inspect(response_body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI vision request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  def project_brief_template do
    read_template(@project_brief_template_path, "")
  end

  def transcribe_audio(audio_binary, mime_type)
      when is_binary(audio_binary) and is_binary(mime_type) do
    if byte_size(audio_binary) > 25_000_000 do
      {:error, :audio_too_large}
    else
      api_url = "https://api.openai.com/v1/audio/transcriptions"
      ext = mime_type_to_extension(mime_type)
      api_key = api_key()

      if !is_binary(api_key) or byte_size(api_key) == 0 do
        Logger.error(
          "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
        )

        {:error, :missing_openai_api_key}
      else
        fields = [
          file: {audio_binary, filename: "meeting.#{ext}", content_type: mime_type},
          model: "whisper-1",
          response_format: "text"
        ]

        req_options = [
          headers: [{"Authorization", "Bearer #{api_key}"}],
          form_multipart: fields,
          retry: :transient,
          max_retries: 6,
          receive_timeout: 120_000
        ]

        case Req.post(api_url, req_options) do
          {:ok, %{status: 200, body: transcript}} when is_binary(transcript) ->
            {:ok, String.trim(transcript)}

          {:ok, %{status: 200, body: %{"text" => text}}} when is_binary(text) ->
            {:ok, String.trim(text)}

          {:ok, %{status: status, body: body}} ->
            Logger.warning("OpenAI transcription error response: #{inspect(body)}")
            {:error, {:http_error, status}}

          {:error, reason} ->
            Logger.warning("OpenAI transcription request error: #{inspect(reason)}")
            {:error, {:request_failed, reason}}
        end
      end
    end
  end

  def generate_images(prompt, opts \\ []) when is_binary(prompt) do
    api_url = "https://api.openai.com/v1/images/generations"
    api_key = api_key()

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      n = Keyword.get(opts, :n, 1)

      body =
        %{
          "model" => Keyword.get(opts, :model, "gpt-image-1"),
          "prompt" => prompt,
          "n" => n,
          "size" => Keyword.get(opts, :size, "auto"),
          "quality" => Keyword.get(opts, :quality, "auto"),
          "output_format" => Keyword.get(opts, :output_format, "png"),
          "background" => Keyword.get(opts, :background, "auto")
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      headers = [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]

      req_options = [
        headers: headers,
        json: body,
        retry: :transient,
        max_retries: 6,
        receive_timeout: 120_000
      ]

      case Req.post(api_url, req_options) do
        {:ok, %{status: 200, body: %{} = response_body}} ->
          {:ok, response_body}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI images error response: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI images request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  def create_video_job(prompt, opts \\ []) when is_binary(prompt) do
    api_url = "https://api.openai.com/v1/videos"
    api_key = api_key()

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      fields =
        [
          prompt: prompt,
          model: Keyword.get(opts, :model, "sora-2"),
          size: Keyword.get(opts, :size, "720x1280"),
          seconds: Keyword.get(opts, :seconds, "4")
        ]
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)

      req_options = [
        headers: [{"Authorization", "Bearer #{api_key}"}],
        form_multipart: fields,
        retry: :transient,
        max_retries: 3,
        receive_timeout: 120_000
      ]

      case Req.post(api_url, req_options) do
        {:ok, %{status: 200, body: %{} = response_body}} ->
          {:ok, response_body}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI video create error response: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI video create request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  def retrieve_video_job(video_id) when is_binary(video_id) do
    api_key = api_key()

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      api_url = "https://api.openai.com/v1/videos/#{video_id}"

      req_options = [
        headers: [{"Authorization", "Bearer #{api_key}"}],
        retry: :transient,
        max_retries: 3,
        receive_timeout: 60_000
      ]

      case Req.get(api_url, req_options) do
        {:ok, %{status: 200, body: %{} = response_body}} ->
          {:ok, response_body}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI video retrieve error response: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI video retrieve request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  def download_video_content(video_id) when is_binary(video_id) do
    api_key = api_key()

    if !is_binary(api_key) or byte_size(api_key) == 0 do
      Logger.error(
        "Missing OpenAI API key; set config :beta_sigma, :openai_api_key or OPENAI_API_KEY"
      )

      {:error, :missing_openai_api_key}
    else
      api_url = "https://api.openai.com/v1/videos/#{video_id}/content"

      req_options = [
        headers: [{"Authorization", "Bearer #{api_key}"}],
        raw: true,
        retry: :transient,
        max_retries: 3,
        receive_timeout: 240_000
      ]

      case Req.get(api_url, req_options) do
        {:ok, %{status: 200, body: body}} when is_binary(body) ->
          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI video content error response: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("OpenAI video content request error: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  def generate_meeting_minutes(transcript, opts \\ []) when is_binary(transcript) do
    with {:ok, response} <-
           send_request_to_openai(
             meeting_minutes_context(),
             meeting_minutes_prompt(transcript),
             Keyword.put_new(opts, :max_tokens, 3_000)
           ) do
      decode_meeting_minutes(response)
    end
  end

  def generate_project_plan(project_attrs, prompt, opts \\ []) do
    with {:ok, response} <-
           send_request_to_openai(
             planner_context(),
             planner_prompt(project_attrs, prompt),
             Keyword.put_new(opts, :max_tokens, 3_000)
           ) do
      decode_project_plan(response)
    end
  end

  def generate_podcast_script(episode_attrs, opts \\ []) when is_map(episode_attrs) do
    with {:ok, response} <-
           send_request_to_openai(
             podcast_script_context(),
             podcast_script_prompt(episode_attrs),
             Keyword.put_new(opts, :max_tokens, 4_000)
           ) do
      decode_podcast_script(response)
    end
  end

  def generate_client_proposal(proposal_attrs, opts \\ []) when is_map(proposal_attrs) do
    with {:ok, response} <-
           send_request_to_openai(
             proposal_builder_context(),
             proposal_builder_prompt(proposal_attrs),
             Keyword.put_new(opts, :max_tokens, 4_500)
           ) do
      decode_client_proposal(response)
    end
  end

  @doc """
  Generates a structured, non-coding interview guide for a candidate. The guide
  walks an interviewer from the candidate's story through their qualifications and
  past work, then into situational judgement questions used to gauge general
  technical ability and reasoning rather than specific coding skills.
  """
  def generate_interview_questions(candidate_attrs, opts \\ []) when is_map(candidate_attrs) do
    with {:ok, response} <-
           send_request_to_openai(
             interview_questions_context(),
             interview_questions_prompt(candidate_attrs),
             Keyword.put_new(opts, :max_tokens, 2_800)
           ) do
      decode_interview_questions(response)
    end
  end

  defp interview_questions_context do
    """
    You are a senior hiring manager preparing a structured, conversational interview guide for a live interview. The interview is NOT a coding test. You want to gauge the candidate's general technical ability, judgement, ownership, communication, and attitude through how they think and talk, not by asking them to write code.

    The questions must be SPECIFIC TO THIS ROLE. Read the role title, department, type, description and requirements carefully and let them drive the questions: probe the actual skills, responsibilities, tools, stakeholders and pressures this role involves. If the role description or requirements are sparse, infer what the role realistically involves from the title and department, then tailor accordingly. Avoid generic questions that could be asked of any candidate for any job.

    Return valid JSON only. Do not wrap the response in markdown fences and do not add commentary.

    Use this exact JSON shape:
    {
      "summary": "1 to 2 sentence note to the interviewer on what to focus on for this candidate and role.",
      "sections": [
        {
          "title": "Their Journey",
          "purpose": "one line on why this section matters",
          "questions": ["question text", "..."]
        }
      ]
    }

    Produce EXACTLY these four sections, in this order, with these titles:
    1. "Their Journey" - how they got to where they are now. Start warm and open: their story, what drew them to this kind of work, key turning points. 3 to 4 questions.
    2. "Qualifications & Foundations" - their education, training, certifications, and how they keep their skills current. Probe depth without being a quiz. 3 to 4 questions.
    3. "Things They've Built & Done" - concrete past work, projects, and impact. Ask them to walk through something they are proud of, their specific role, trade-offs they made, and outcomes. 4 to 5 questions.
    4. "Situational Judgement" - hypothetical "what would you do if..." scenarios relevant to this role that reveal problem solving, prioritisation, collaboration, and handling pressure or ambiguity. 4 to 5 questions.

    Writing rules:
    - Questions must be open-ended and conversational, never yes/no.
    - Do NOT ask the candidate to write, debug, or read code. Keep it about reasoning, decisions, and experience.
    - Across ALL sections, reference the role's actual skills, responsibilities, tools or domain so each question clearly belongs to this role and not a generic interview.
    - Make situational questions concrete scenarios this person would genuinely face in this role (e.g. tight deadline, conflicting stakeholders, an approach that failed, unclear requirements).
    - Keep each question to a single clear sentence.
    - Tailor wording to the role and candidate context where it sharpens the question; avoid generic filler.
    """
  end

  defp interview_questions_prompt(candidate_attrs) do
    snapshot = %{
      candidate_name: get_value(candidate_attrs, "candidate_name"),
      role_title: get_value(candidate_attrs, "role_title"),
      role_department: get_value(candidate_attrs, "role_department"),
      role_type: get_value(candidate_attrs, "role_type"),
      role_description: get_value(candidate_attrs, "role_description"),
      role_requirements: get_value(candidate_attrs, "role_requirements"),
      cover_letter: get_value(candidate_attrs, "cover_letter"),
      linkedin_url: get_value(candidate_attrs, "linkedin_url")
    }

    """
    Candidate and role context JSON:
    #{Jason.encode!(snapshot)}

    Ground every section in this specific role. Use the role_description and role_requirements to decide what skills, responsibilities and day-to-day realities matter, and aim the questions at those. Build the interview guide the interviewer can read live during the conversation.
    """
  end

  defp decode_interview_questions(response) when is_binary(response) do
    response
    |> normalize_json_payload()
    |> Jason.decode()
    |> case do
      {:ok, %{} = payload} ->
        sections = normalize_interview_sections(payload["sections"] || payload["guide"])

        if sections != [] do
          {:ok,
           %{
             "summary" => normalize_brief(fetch_any(payload, ["summary", "focus", "note"])),
             "sections" => sections
           }}
        else
          {:error, :invalid_interview_guide}
        end

      {:ok, _other} ->
        {:error, :invalid_interview_guide}

      {:error, reason} ->
        Logger.warning("Could not decode OpenAI interview guide: #{inspect(reason)}")
        {:error, :invalid_json}
    end
  end

  defp normalize_interview_sections(sections) when is_list(sections) do
    sections
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn section ->
      title = fetch_any(section, ["title", "name", "heading"])
      purpose = fetch_any(section, ["purpose", "focus", "goal"])
      questions = fetch_any(section, ["questions", "items", "prompts"])

      questions =
        questions
        |> List.wrap()
        |> Enum.map(&normalize_question/1)
        |> Enum.reject(&is_nil/1)

      if is_binary(title) and String.trim(title) != "" and questions != [] do
        %{
          "title" => String.trim(title),
          "purpose" => normalize_brief(purpose),
          "questions" => questions
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_interview_sections(_sections), do: []

  defp normalize_question(question) when is_binary(question) do
    case String.trim(question) do
      "" -> nil
      text -> text
    end
  end

  defp normalize_question(question) when is_map(question) do
    question |> fetch_any(["question", "text", "prompt"]) |> normalize_question()
  end

  defp normalize_question(_question), do: nil

  def podcast_base_template do
    read_template(@podcast_base_template_path, @default_podcast_base_template)
  end

  defp podcast_script_context do
    """
    You are a senior podcast producer preparing a host-ready run-of-show for an interview podcast about how great engineering teams are built.

    Before writing the script, infer what the guest's company does using your training knowledge: industry, product or service, customer segment, well-known engineering or business challenges, notable public stories, and any technical signals (stack, scale, recent launches). If the company is unfamiliar, reason from its name, the guest's role, and any provided notes to make a sensible, clearly-hedged inference. Do not fabricate specific numbers, funding rounds, or named customers.

    Use this segment-by-segment template as the script's spine. Keep all segment titles, timing markers, and bullet purpose lines, but rewrite the bullet questions so each one is tailored to this specific guest and company:

    #{podcast_base_template()}

    Return valid JSON only. Do not wrap the response in markdown fences and do not add commentary.

    Use this exact JSON shape:
    {
      "guest_company_brief": "2 to 4 sentence summary of what the company does, who it serves, and why their engineering story is interesting. Hedge if uncertain.",
      "podcast_script": "# Episode Title\\n\\n## Guest\\n...\\n\\n## Run of show\\n... full segment-by-segment script following the template ..."
    }

    Rules for podcast_script:
    - Markdown formatted, ready for the host to read on the day of recording.
    - Keep every segment from the template (Cold Open, Origin Story, Tech Stack Decisions, Building the Team, Staying Great Under Pressure, Rapid Fire, Close) with its time range.
    - Open each segment with a one-line producer note about its purpose, then list 4 to 8 tailored questions for that segment.
    - Questions must reference the guest's company, role, or sector where it makes the question sharper. Avoid generic phrasing.
    - Include a "Cold open hook" line under Segment 1 with a quotable teaser tailored to the guest.
    - In Segment 7, leave placeholders for the guest's links (newsletter, LinkedIn, company site) marked as [guest to confirm].
    - Do not invent quotes attributed to the guest.
    """
  end

  defp podcast_script_prompt(episode_attrs) do
    snapshot = %{
      podcast_name: get_value(episode_attrs, "podcast_name"),
      episode_title: get_value(episode_attrs, "episode_title"),
      guest_name: get_value(episode_attrs, "guest_name"),
      guest_company: get_value(episode_attrs, "guest_company"),
      guest_contact: get_value(episode_attrs, "guest_contact"),
      recording_date: get_value(episode_attrs, "recording_date"),
      notes: get_value(episode_attrs, "notes"),
      questions: get_value(episode_attrs, "questions")
    }

    """
    Episode details:
    #{Jason.encode!(snapshot)}

    Produce a tailored run-of-show the host can read live. Tailor every question to this guest and their company.
    """
  end

  defp proposal_builder_context do
    """
    You are a senior solutions architect and proposal lead helping an internal ERP team turn messy discovery notes into a polished client proposal.

    Return valid JSON only. Do not wrap the response in markdown fences and do not add commentary.

    Use this exact JSON shape:
    {
      "proposal_title": "string",
      "summary": "2 to 4 sentence executive summary",
      "solution_areas": ["Finance ERP", "HR & Payroll"],
      "delivery_phases": [
        {
          "name": "Discovery",
          "focus": "short explanation of the phase"
        }
      ],
      "markdown_proposal": "# Proposal Title\\n..."
    }

    Ground the proposal in the provided notes. If the notes imply assumptions, state them clearly as assumptions instead of presenting them as confirmed facts.

    The markdown_proposal must be client-ready and tailored to the requested proposal_type. It should include:
    - Title
    - Client Context
    - Objectives
    - Recommended Solution
    - Proposed Modules / Workstreams
    - Delivery Approach or Phases
    - Key Assumptions and Dependencies
    - Optional AI / automation opportunities when they are genuinely useful
    - Next Steps

    Writing rules:
    - Keep the tone practical, persuasive, and specific.
    - Make the solution feel like something a real delivery team can implement.
    - Prefer concrete modules and workflows over vague transformation language.
    - Mention integrations, permissions, rollout sequencing, training, and change management where relevant.
    - If a website revamp or newsroom workflow is mentioned, include it as a separate workstream rather than burying it.
    - For executive_summary proposal types, keep the markdown shorter and more outcome-focused.
    - For implementation_plan proposal types, emphasize phases, dependencies, and rollout order.
    - For scope_of_work proposal types, emphasize deliverables, in-scope items, and boundaries.
    - For technical_proposal proposal types, emphasize architecture, modules, workflows, and delivery reasoning.
    """
  end

  defp proposal_builder_prompt(proposal_attrs) do
    snapshot = %{
      title: get_value(proposal_attrs, "title"),
      client_name: get_value(proposal_attrs, "client_name"),
      proposal_type: get_value(proposal_attrs, "proposal_type"),
      audience: get_value(proposal_attrs, "audience"),
      objective: get_value(proposal_attrs, "objective"),
      reference_url: get_value(proposal_attrs, "reference_url"),
      source_notes: get_value(proposal_attrs, "source_notes")
    }

    """
    Proposal input JSON:
    #{Jason.encode!(snapshot)}

    Build a proposal the team can refine and send to the client.
    """
  end

  defp decode_podcast_script(response) when is_binary(response) do
    response
    |> normalize_json_payload()
    |> Jason.decode()
    |> case do
      {:ok, %{} = payload} ->
        script = fetch_any(payload, ["podcast_script", "script", "run_of_show"])
        brief = fetch_any(payload, ["guest_company_brief", "company_brief", "brief"])

        if is_binary(script) and String.trim(script) != "" do
          {:ok,
           %{
             "podcast_script" => String.trim(script),
             "guest_company_brief" => normalize_brief(brief)
           }}
        else
          {:error, :invalid_podcast_script}
        end

      {:ok, _other} ->
        {:error, :invalid_podcast_script}

      {:error, reason} ->
        Logger.warning("Could not decode OpenAI podcast script: #{inspect(reason)}")
        {:error, :invalid_json}
    end
  end

  defp decode_client_proposal(response) when is_binary(response) do
    response
    |> normalize_json_payload()
    |> Jason.decode()
    |> case do
      {:ok, %{} = payload} ->
        title = fetch_any(payload, ["proposal_title", "title"])
        summary = fetch_any(payload, ["summary", "executive_summary"])
        markdown = fetch_any(payload, ["markdown_proposal", "proposal_markdown", "markdown"])

        if is_binary(title) and String.trim(title) != "" and
             is_binary(summary) and String.trim(summary) != "" and
             is_binary(markdown) and String.trim(markdown) != "" do
          {:ok, payload}
        else
          {:error, :invalid_client_proposal}
        end

      {:ok, _other} ->
        {:error, :invalid_client_proposal}

      {:error, reason} ->
        Logger.warning("Could not decode OpenAI client proposal: #{inspect(reason)}")
        {:error, :invalid_json}
    end
  end

  defp normalize_brief(nil), do: nil

  defp normalize_brief(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_brief(_), do: nil

  defp planner_context do
    """
    You are helping a delivery team turn a rough project request into a usable project brief and an initial task backlog.

    Return valid JSON only. Do not wrap the response in markdown fences and do not add commentary.

    Use this exact JSON shape:
    {
      "document_name": "supplier_onboarding_portal_project_document.md",
      "project_summary": "short paragraph",
      "markdown_brief": "# Project Name\\n...",
      "tasks": [
        {
          "phase": "Discovery|Foundation|Backend|Frontend|QA|Launch",
          "title": "task title",
          "description": "short task description",
          "priority": "low|medium|high|urgent",
          "estimated_hours": 1
        }
      ]
    }

    Rules:
    - Return a document_name ending in .md and formatted like a real project document filename.
    - Keep the summary to 1 to 3 sentences.
    - The markdown brief should closely follow this template structure and read like a proper technical project document.
    - Create 10 to 18 practical implementation tasks.
    - Order tasks from first to last.
    - Make the tasks technically specific, not generic.
    - Include discovery, architecture, data modeling, backend implementation, frontend or workflow implementation, testing, deployment or rollout, and documentation tasks when relevant.
    - Every task must include a phase chosen from Discovery, Foundation, Backend, Frontend, QA, Launch.
    - Prefer smaller executable tasks over a few broad tasks.
    - Mention important integrations, permissions, validation, error handling, observability, and QA work when they matter for the request.
    - Use only the priority values low, medium, high, urgent.
    - Use a number for estimated_hours or null if unknown.
    - Avoid due dates unless they were explicitly provided.

    Markdown template:
    #{project_brief_template()}
    """
  end

  defp read_template(path, fallback) do
    case File.read(path) do
      {:ok, contents} ->
        contents

      {:error, reason} ->
        Logger.warning("Could not read template #{path}: #{inspect(reason)}")
        fallback
    end
  end

  defp planner_prompt(project_attrs, prompt) do
    project_snapshot = %{
      name: get_value(project_attrs, "name"),
      description: get_value(project_attrs, "description"),
      status: get_value(project_attrs, "status"),
      start_date: get_value(project_attrs, "start_date"),
      deadline: get_value(project_attrs, "deadline"),
      budget: get_value(project_attrs, "budget")
    }

    """
    Existing project fields:
    #{Jason.encode!(project_snapshot)}

    User description of the requested project:
    #{String.trim(prompt)}

    Build a concise but specific implementation brief and an initial backlog that a project team can start from immediately.
    """
  end

  defp decode_project_plan(response) when is_binary(response) do
    response
    |> normalize_json_payload()
    |> Jason.decode()
    |> case do
      {:ok, raw_plan} when is_map(raw_plan) ->
        plan = normalize_project_plan(raw_plan)

        if valid_project_plan?(plan) do
          {:ok, plan}
        else
          {:error, :invalid_project_plan}
        end

      {:ok, _other} ->
        {:error, :invalid_project_plan}

      {:error, reason} ->
        Logger.warning("Could not decode OpenAI project plan: #{inspect(reason)}")
        {:error, :invalid_json}
    end
  end

  defp normalize_json_payload(response) do
    trimmed =
      response
      |> String.trim()
      |> String.replace(~r/^```(?:json)?\s*/i, "")
      |> String.replace(~r/\s*```$/, "")

    case Regex.run(~r/\{.*\}/s, trimmed) do
      [json] -> json
      _ -> trimmed
    end
  end

  defp meeting_minutes_context do
    """
    You are an expert meeting assistant. Given a raw meeting transcript, extract structured minutes.

    Return valid JSON only. Do not wrap in markdown fences. Do not add commentary.

    Use this exact JSON shape:
    {
      "title": "Short descriptive meeting title",
      "summary": "2-3 sentence summary of what was discussed and decided",
      "participants": ["Name One", "Name Two"],
      "decisions": ["Decision made during the meeting"],
      "markdown_minutes": "# Meeting Title\\n\\n## Attendees\\n...",
      "action_items": [
        {
          "title": "task title",
          "description": "short description",
          "assignee": "Name or null",
          "priority": "low|medium|high|urgent",
          "estimated_hours": 2
        }
      ]
    }

    Rules:
    - Extract real participant names from context clues in the transcript. If none are identifiable, return an empty array.
    - Decisions are concrete outcomes, not discussion points.
    - Action items must be specific and executable.
    - The markdown_minutes should be a professional document: Attendees, Agenda/Topics Discussed, Key Decisions, Action Items, Next Steps sections.
    - Use only priority values: low, medium, high, urgent.
    - estimated_hours should be a number or null.
    """
  end

  defp meeting_minutes_prompt(transcript) do
    """
    Raw meeting transcript:
    #{String.trim(transcript)}

    Extract professional minutes and actionable tasks.
    """
  end

  defp decode_meeting_minutes(response) when is_binary(response) do
    response
    |> normalize_json_payload()
    |> Jason.decode()
    |> case do
      {:ok, minutes} when is_map(minutes) ->
        if valid_meeting_minutes?(minutes) do
          {:ok, minutes}
        else
          {:error, :invalid_meeting_minutes}
        end

      {:ok, _other} ->
        {:error, :invalid_meeting_minutes}

      {:error, reason} ->
        Logger.warning("Could not decode OpenAI meeting minutes: #{inspect(reason)}")
        {:error, :invalid_json}
    end
  end

  defp valid_meeting_minutes?(minutes) when is_map(minutes) do
    title = fetch_any(minutes, ["title", "name"])
    markdown = fetch_any(minutes, ["markdown_minutes", "minutes"])
    action_items = fetch_any(minutes, ["action_items", "tasks"])

    is_binary(title) and String.trim(title) != "" and
      (is_binary(markdown) or is_list(action_items))
  end

  defp valid_meeting_minutes?(_minutes), do: false

  defp mime_type_to_extension(mime_type) do
    mime_type
    |> String.trim()
    |> String.downcase()
    |> case do
      "audio/webm" -> "webm"
      "audio/ogg" -> "ogg"
      "audio/mp4" -> "mp4"
      "audio/mpeg" -> "mpeg"
      "audio/mp3" -> "mp3"
      "audio/wav" -> "wav"
      "audio/x-wav" -> "wav"
      _ -> "webm"
    end
  end

  def api_key do
    Application.get_env(:beta_sigma, :openai_api_key) ||
      System.get_env("OPENAI_API_KEY") ||
      ""
  end

  defp normalize_project_plan(raw_plan) do
    flat_tasks = raw_plan |> fetch_any(["tasks", "backlog", "initial_tasks"]) |> normalize_tasks()

    phased_tasks =
      raw_plan |> fetch_any(["phases", "task_groups", "workstreams"]) |> normalize_phases()

    markdown_brief =
      fetch_any(raw_plan, [
        "markdown_brief",
        "project_document",
        "project_brief",
        "brief",
        "markdown"
      ])

    markdown_tasks = markdown_brief |> normalize_markdown_backlog()

    tasks =
      case {flat_tasks, phased_tasks, markdown_tasks} do
        {[], [], extracted} -> extracted
        {[], grouped, _extracted} -> grouped
        {flat, [], _extracted} -> flat
        {flat, grouped, _extracted} -> flat ++ grouped
      end

    %{
      "document_name" => fetch_any(raw_plan, ["document_name", "file_name", "filename"]),
      "project_summary" =>
        fetch_any(raw_plan, ["project_summary", "summary", "overview", "project_overview"]),
      "markdown_brief" => markdown_brief,
      "tasks" => tasks
    }
  end

  defp valid_project_plan?(%{"tasks" => tasks} = plan) when is_list(tasks) do
    tasks != [] or is_binary(plan["markdown_brief"]) or is_binary(plan["project_summary"])
  end

  defp valid_project_plan?(_plan), do: false

  defp normalize_tasks(tasks) when is_list(tasks) do
    tasks
    |> Enum.map(&normalize_task_entry(&1, nil))
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_tasks(_tasks), do: []

  defp normalize_phases(phases) when is_list(phases) do
    phases
    |> Enum.flat_map(fn phase_group ->
      phase_name =
        case phase_group do
          %{} ->
            fetch_any(phase_group, ["phase", "name", "title", "label"])

          _ ->
            nil
        end

      phase_tasks =
        case phase_group do
          %{} -> fetch_any(phase_group, ["tasks", "items", "backlog"])
          _ -> nil
        end

      phase_tasks
      |> List.wrap()
      |> Enum.map(&normalize_task_entry(&1, phase_name))
      |> Enum.reject(&is_nil/1)
    end)
  end

  defp normalize_phases(_phases), do: []

  defp normalize_task_entry(task, phase_name) when is_binary(task) do
    title =
      task
      |> String.trim()

    if title == "" do
      nil
    else
      %{"phase" => phase_name, "title" => title}
    end
  end

  defp normalize_task_entry(task, phase_name) when is_map(task) do
    title = fetch_any(task, ["title", "name", "task"])

    if is_binary(title) and String.trim(title) != "" do
      %{
        "phase" => fetch_any(task, ["phase", "group"]) || phase_name,
        "title" => title,
        "description" => fetch_any(task, ["description", "details", "notes"]),
        "priority" => fetch_any(task, ["priority", "severity"]),
        "estimated_hours" => fetch_any(task, ["estimated_hours", "hours", "estimate"])
      }
    else
      nil
    end
  end

  defp normalize_task_entry(_task, _phase_name), do: nil

  defp normalize_markdown_backlog(markdown) when is_binary(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.reduce({false, nil, []}, fn line, {in_backlog?, current_phase, tasks} ->
      trimmed = String.trim(line)

      cond do
        trimmed == "" ->
          {in_backlog?, current_phase, tasks}

        heading = parse_markdown_heading(trimmed) ->
          update_markdown_context(heading, in_backlog?, current_phase, tasks)

        task_text = parse_markdown_bullet(trimmed) ->
          if in_backlog? do
            task = build_markdown_task(task_text, current_phase)
            {in_backlog?, current_phase, [task | tasks]}
          else
            {in_backlog?, current_phase, tasks}
          end

        true ->
          {in_backlog?, current_phase, tasks}
      end
    end)
    |> elem(2)
    |> Enum.reverse()
  end

  defp normalize_markdown_backlog(_markdown), do: []

  defp parse_markdown_heading(line) do
    case Regex.run(~r/^(\#{2,6})\s+(.+)$/, line) do
      [_, hashes, title] -> %{level: String.length(hashes), title: String.trim(title)}
      _ -> nil
    end
  end

  defp parse_markdown_bullet(line) do
    case Regex.run(~r/^[-*]\s+(.+)$/, line) do
      [_, text] -> String.trim(text)
      _ -> nil
    end
  end

  defp update_markdown_context(%{level: level, title: title}, in_backlog?, current_phase, tasks) do
    normalized = title |> String.downcase() |> String.trim()

    cond do
      normalized in ["initial task backlog", "task backlog", "delivery plan"] ->
        {true, current_phase, tasks}

      String.starts_with?(normalized, "phase ") ->
        {true, extract_phase_name(title), tasks}

      level >= 3 and in_backlog? and
          title in ["Discovery", "Foundation", "Backend", "Frontend", "QA", "Launch"] ->
        {true, title, tasks}

      level <= 2 and in_backlog? ->
        {false, nil, tasks}

      true ->
        {in_backlog?, current_phase, tasks}
    end
  end

  defp extract_phase_name(title) when is_binary(title) do
    case Regex.run(~r/^Phase\s+\d+\s*:\s*(.+)$/i, title) do
      [_, phase] -> String.trim(phase)
      _ -> String.trim(title)
    end
  end

  defp build_markdown_task(task_text, phase_name) do
    {title, description} =
      case String.split(task_text, ":", parts: 2) do
        [single] -> {String.trim(single), nil}
        [task_title, task_description] -> {String.trim(task_title), String.trim(task_description)}
      end

    %{
      "phase" => phase_name,
      "title" => title,
      "description" => empty_to_nil(description),
      "priority" => "medium",
      "estimated_hours" => nil
    }
  end

  defp empty_to_nil(nil), do: nil

  defp empty_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp fetch_any(map, keys) when is_map(map) and is_list(keys) do
    Enum.find_value(keys, fn key ->
      Map.get(map, key) ||
        Enum.find_value(map, fn
          {atom_key, value} when is_atom(atom_key) ->
            if Atom.to_string(atom_key) == key, do: value

          _other ->
            nil
        end)
    end)
  end

  defp get_value(map, key) do
    case key do
      "name" -> Map.get(map, "name") || Map.get(map, :name)
      "description" -> Map.get(map, "description") || Map.get(map, :description)
      "status" -> Map.get(map, "status") || Map.get(map, :status)
      "start_date" -> Map.get(map, "start_date") || Map.get(map, :start_date)
      "deadline" -> Map.get(map, "deadline") || Map.get(map, :deadline)
      "budget" -> Map.get(map, "budget") || Map.get(map, :budget)
      _ -> Map.get(map, key)
    end
  end
end
