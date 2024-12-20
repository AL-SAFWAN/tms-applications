import { z } from "zod";

export const loginSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(1, "Password is required"),
});

export type LoginFormInputs = z.infer<typeof loginSchema>;

export const emailSchema = z.object({
  email: z.string().email("Invalid email address"),
});

export type EmailFormInputs = z.infer<typeof emailSchema>;

export const signUpSchema = z
  .object({
    email: z
      .string()
      .email("Invalid email address")
      .max(255, "Email must be less than 255 characters"),
    password: z
      .string()
      .min(1, "Password is required")
      .regex(/^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z]).{8,}$/, ""),
    confirmPassword: z.string().min(1, "Enter password again"),
    firstName: z
      .string()
      .min(1, "First name is required")
      .max(255, "First name must be less than 255 characters"),
    lastName: z
      .string()
      .min(1, "Last name is required")
      .max(255, "Last name must be less than 255 characters"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  });

export type SignUpFormInputs = z.infer<typeof signUpSchema>;

export const resetPasswordSchema = z
  .object({
    password: z
      .string()
      .min(1, "Password is required")
      .regex(/^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z]).{8,}$/, ""),
    confirmPassword: z.string().min(1, "Enter password again"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  });

export type ResetPasswordInputs = z.infer<typeof resetPasswordSchema>;

export enum roleEnum {
  requester = "requester",
  admin = "admin",
  agent = "agent",
}
export interface User {
  email: string;
  id: string;
  isActive: boolean;
  role: roleEnum;
  firstName: string;
  lastName: string;
  password: string;
  createdAt: Date;
}
