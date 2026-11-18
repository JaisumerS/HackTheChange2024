import { NextResponse } from "next/server";
import OpenAI from "openai";

export const runtime = "nodejs";

export async function POST(req) {
  // 1. Check that the API key exists
  const apiKey = process.env.OPENAI_KEY;

  if (!apiKey) {
    console.error("OPENAI_KEY is missing");

    return NextResponse.json(
      { error: "AI service is not configured" },
      { status: 503 }
    );
  }

  // 2. Parse the incoming JSON
  let body;

  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON body" },
      { status: 400 }
    );
  }

  const { messages, conflict } = body ?? {};

  // 3. Validate the messages
  const validMessages =
    Array.isArray(messages) &&
    messages.length > 0 &&
    messages.length <= 10 &&
    messages.every(
      (message) =>
        message &&
        ["user", "assistant"].includes(message.role) &&
        typeof message.content === "string" &&
        message.content.trim().length > 0 &&
        message.content.length <= 4000
    );

  if (!validMessages) {
    return NextResponse.json(
      { error: "Invalid messages or too many messages" },
      { status: 400 }
    );
  }

  // 4. Validate the optional conflict
  if (
    conflict !== undefined &&
    (typeof conflict !== "string" || conflict.length > 500)
  ) {
    return NextResponse.json(
      { error: "Invalid conflict" },
      { status: 400 }
    );
  }

  try {
    // 5. Initialize OpenAI inside POST
    const openai = new OpenAI({
      apiKey,
      ...(process.env.OPENAI_ORG && {
        organization: process.env.OPENAI_ORG,
      }),
    });

    // 6. Generate the response
    const chatCompletion =
      await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          ...(conflict?.trim()
            ? [
                {
                  role: "system",
                  content: `This chat is focused on the topic of: ${conflict.trim()}`,
                },
              ]
            : []),
          ...messages,
        ],
      });

    const responseMessage =
      chatCompletion.choices[0]?.message?.content;

    if (!responseMessage) {
      throw new Error("Empty OpenAI response");
    }

    // 7. Return the completion to the frontend
    return NextResponse.json(
      { completion: responseMessage },
      { status: 200 }
    );
  } catch (error) {
    console.error("OpenAI request failed:", error);

    return NextResponse.json(
      { error: "Failed to generate AI response" },
      { status: 500 }
    );
  }
}
